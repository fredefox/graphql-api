{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}

-- | An example GraphQL schema, used in our end-to-end tests.
--
-- Based on the example schema given in the GraphQL spec. See
-- <https://facebook.github.io/graphql/#sec-Validation>.
--
-- Here's the full schema:
--
-- @
-- enum DogCommand { SIT, DOWN, HEEL }
--
-- type Dog implements Pet {
--   name: String!
--   nickname: String
--   barkVolume: Int
--   doesKnowCommand(dogCommand: DogCommand!): Boolean!
--   isHousetrained(atOtherHomes: Boolean): Boolean!
--   owner: Human
-- }
--
-- interface Sentient {
--   name: String!
-- }
--
-- interface Pet {
--   name: String!
-- }
--
-- type Alien implements Sentient {
--   name: String!
--   homePlanet: String
-- }
--
-- type Human implements Sentient {
--   name: String!
-- }
--
-- enum CatCommand { JUMP }
--
-- type Cat implements Pet {
--   name: String!
--   nickname: String
--   doesKnowCommand(catCommand: CatCommand!): Boolean!
--   meowVolume: Int
-- }
--
-- union CatOrDog = Cat | Dog
-- union DogOrHuman = Dog | Human
-- union HumanOrAlien = Human | Alien
-- @
--
-- Unlike the spec, we don't define a @QueryRoot@ type here, instead
-- encouraging test modules to define their own as appropriate to their needs.
--
-- We'll repeat bits of the schema below, explaining how they translate into
-- Haskell as we go.

module ExampleSchema
  ( DogCommand(..)
  , Dog
  , Sentient
  , Pet
  , Alien
  , Human
  , CatCommand(..)
  , Cat
  , CatOrDog
  , DogOrHuman
  , HumanOrAlien
  ) where

import Protolude hiding (Enum)

import GraphQL.API
  ( GraphQLEnum(..)
  , Enum
  , Object
  , Field
  , Argument
  , Interface
  , Union
  , (:>)
  , Defaultable(..)
  )
import GraphQL.Value
  ( pattern ValueEnum
  , ToValue(..)
  )
import GraphQL.Internal.Name (Name(unName))

-- | A command that can be given to a 'Dog'.
--
-- @
-- enum DogCommand { SIT, DOWN, HEEL }
-- @
--
-- To define this in Haskell we need to do three things:
--
--  1. Define a sum type with nullary constructors to represent the enum
--     (here, 'DogCommandEnum')
--  2. Make it an instance of 'GraphQLEnum'
--  3. Wrap the sum type in 'Enum', e.g. @Enum "DogCommand" DogCommandEnum@
--     so it can be placed in a schema.
data DogCommand = Sit | Down | Heel deriving (Show, Eq, Ord, Generic)

instance Defaultable DogCommand where
  -- Explicitly want no default for dogCommand
  defaultFor (unName -> "dogCommand") = Nothing
  -- DogCommand shouldn't be used elsewhere in schema, but who can say?
  defaultFor _ = Nothing

instance GraphQLEnum DogCommand

-- TODO: Probably shouldn't have to do this for enums.
instance ToValue DogCommand where
  toValue = ValueEnum . enumToValue

-- | A dog.
--
-- This is an example of a GraphQL \"object\".
--
-- @
-- type Dog implements Pet {
--   name: String!
--   nickname: String
--   barkVolume: Int
--   doesKnowCommand(dogCommand: DogCommand!): Boolean!
--   isHousetrained(atOtherHomes: Boolean): Boolean!
--   owner: Human
-- }
-- @
--
-- To define it in Haskell, we use 'Object'. The first argument is the name of
-- the object (here, @"Dog"@). The second is a list of interfaces implemented
-- by the object (here, only 'Pet').
--
-- The third, final, and most interesting argument is the list of fields the
-- object has. Fields can look one of two ways:
--
-- @
-- Field "name" Text
-- @
--
-- for a field that takes no arguments. This field would be called @name@ and
-- is guaranteed to return some text if queried.
--
-- A field that takes arguments looks like this:
--
-- @
-- Argument "dogCommand" DogCommand :> Field "doesKnowCommand" Bool
-- @
--
-- Here, the field is named @doesKnowCommand@ and it takes a single
-- argument--a 'DogCommand'--and returns a 'Bool'. Note that this is in
-- reverse order to the GraphQL schema, which represents this field as:
--
-- @
--   doesKnowCommand(dogCommand: DogCommand!): Boolean!
-- @
--
-- Also note that all fields and arguments are "non-null" by default. If you
-- want a field to be nullable, give it a 'Maybe' type, e.g.
--
-- @
--   nickname: String
-- @
--
-- @nickname@ is nullable, so we represent the field in Haskell as:
--
-- @
--   Field "nickname" (Maybe Text)
-- @
type Dog = Object "Dog" '[Pet]
  '[ Field "name" Text
   , Field "nickname" (Maybe Text)
   , Field "barkVolume" Int32
   , Argument "dogCommand" (Enum "DogCommand" DogCommand) :> Field "doesKnowCommand" Bool
   , Argument "atOtherHomes" (Maybe Bool) :> Field "isHouseTrained" Bool
   , Field "owner" Human
   ]

-- | Sentient beings have names.
--
-- This defines an interface, 'Sentient', that objects can implement.
--
-- @
-- interface Sentient {
--   name: String!
-- }
-- @
type Sentient = Interface "Sentient" '[Field "name" Text]

-- | Pets have names too.
--
-- This defines an interface, 'Pet', that objects can implement.
--
-- @
-- interface Pet {
--   name: String!
-- }
-- @
type Pet = Interface "Pet" '[Field "name" Text]

-- | An alien.
--
-- See 'Dog' for more details on how to define an object type for GraphQL.
--
-- @
-- type Alien implements Sentient {
--   name: String!
--   homePlanet: String
-- }
-- @
type Alien = Object "Alien" '[Sentient]
  '[ Field "name" Text
   , Field "homePlanet" (Maybe Text)
   ]

-- | Humans are sentient.
--
-- See 'Dog' for more details on how to define an object type for GraphQL.
--
-- @
-- type Human implements Sentient {
--   name: String!
-- }
-- @
type Human = Object "Human" '[Sentient]
  '[ Field "name" Text
   ]

-- TODO: Extend example to cover unions, interfaces and lists by giving humans
-- a list of pets and a list of cats & dogs.

-- | Cats can jump.
--
-- See 'DogCommandEnum' for more details on defining an enum for GraphQL.
--
-- The interesting thing about 'CatCommandEnum' is that it's an enum that has
-- only one possible value.
--
-- @
-- enum CatCommand { JUMP }
-- @
data CatCommand = Jump deriving Generic

instance Defaultable CatCommand where
  defaultFor _ = empty

instance GraphQLEnum CatCommand

-- | A cat.
--
-- See 'Dog' for more details on how to define an object type for GraphQL.
--
-- @
-- type Cat implements Pet {
--   name: String!
--   nickname: String
--   doesKnowCommand(catCommand: CatCommand!): Boolean!
--   meowVolume: Int
-- }
-- @
type Cat = Object "Cat" '[Pet]
  '[ Field "name" Text
   , Field "nickName" (Maybe Text)
   , Argument "catCommand" (Enum "CatCommand" CatCommand) :> Field "doesKnowCommand" Bool
   , Field "meowVolume" Int32
   ]

-- | Either a cat or a dog. (Pick dog, dogs are awesome).
--
-- A 'Union' is used when you want to return one of short list of known
-- types.
--
-- You define them in GraphQL like so:
--
-- @
-- union CatOrDog = Cat | Dog
-- @
--
-- To translate this to Haskell, define a new type using 'Union'. The first
-- argument is the name of the union, here @"CatOrDog"@, and the second
-- argument is the list of possible types of the union. These must be objects,
-- defined with 'Object'.
type CatOrDog = Union "CatOrDog" '[Cat, Dog]

-- | Either a dog or a human. (Pick dog, dogs are awesome).
--
-- See 'CatOrDog' for more details on defining a union.
--
-- @
-- union DogOrHuman = Dog | Human
-- @
type DogOrHuman = Union "DogOrHuman" '[Dog, Human]

-- | Either a human or an alien. (Pick dog, dogs are awesome).
--
-- See 'CatOrDog' for more details on defining a union.
--
-- @
-- union HumanOrAlien = Human | Alien
-- @
type HumanOrAlien = Union "HumanOrAlien" '[Human, Alien]

{-# LANGUAGE TemplateHaskell, TypeOperators, MultiParamTypeClasses,
  FlexibleInstances, FlexibleContexts, UndecidableInstances,
  ConstraintKinds #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Examples.EvalM
-- Copyright   :  (c) 2011 Patrick Bahr, Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Tom Hvitved <hvitved@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- Monadic Expression Evaluation
--
-- The example illustrates how to use compositional data types to implement
-- a small expression language, with a sub language of values, and a monadic
-- evaluation function mapping expressions to values.
--
--------------------------------------------------------------------------------

module Examples.EvalM where

import Data.Comp
import Data.Comp.Derive
import Control.Monad (liftM)
import Examples.Common

-- Monadic term evaluation algebra
class EvalM f v where
  evalAlgM :: AlgM Maybe f (Term v)

$(derive [liftSum] [''EvalM])

-- Lift the monadic evaluation algebra to a monadic catamorphism
evalM :: (Traversable f, EvalM f v) => Term f -> Maybe (Term v)
evalM = cataM evalAlgM

instance {-# OVERLAPPABLE #-} (f :<: v) => EvalM f v where
  evalAlgM = return . inject -- default instance

instance {-# OVERLAPPABLE #-} (Value :<: v) => EvalM Op v where
  evalAlgM (Add x y)  = do n1 <- projC x
                           n2 <- projC y
                           return $ iConst $ n1 + n2
  evalAlgM (Mult x y) = do n1 <- projC x
                           n2 <- projC y
                           return $ iConst $ n1 * n2
  evalAlgM (Fst v)    = liftM fst $ projP v
  evalAlgM (Snd v)    = liftM snd $ projP v

projC :: (Value :<: v) => Term v -> Maybe Int
projC v = case project v of
            Just (Const n) -> return n
            _ -> Nothing

projP :: (Value :<: v) => Term v -> Maybe (Term v, Term v)
projP v = case project v of
            Just (Pair x y) -> return (x,y)
            _ -> Nothing

-- Example: evalMEx = Just (iConst 5)
evalMEx :: Maybe (Term Value)
evalMEx = evalM (iConst 1 `iAdd` (iConst 2 `iMult` iConst 2) :: Term Sig)

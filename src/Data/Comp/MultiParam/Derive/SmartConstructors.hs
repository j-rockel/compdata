{-# LANGUAGE TemplateHaskell #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Data.Comp.MultiParam.Derive.SmartConstructors
-- Copyright   :  (c) 2011 Patrick Bahr, Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Tom Hvitved <hvitved@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- Automatically derive smart constructors for parametric types.
--
--------------------------------------------------------------------------------

module Data.Comp.MultiParam.Derive.SmartConstructors 
    (
     smartConstructors
    ) where

import Language.Haskell.TH hiding (Cxt)
import Data.Comp.Derive.Utils
import Data.Comp.MultiParam.Sum
import Data.Comp.MultiParam.Term
import Control.Monad

{-| Derive smart constructors for a type constructor of any parametric kind
 taking at least three arguments. The smart constructors are similar to the
 ordinary constructors, but an 'inject' is automatically inserted. -}
smartConstructors :: Name -> Q [Dec]
smartConstructors fname = do
    TyConI (DataD _cxt tname targs constrs _deriving) <- abstractNewtypeQ $ reify fname
    let iVar = tyVarBndrName $ last targs
    let cons = map (\con -> (abstractConType con, iTp iVar con)) constrs
    liftM concat $ mapM (genSmartConstr (map tyVarBndrName targs) tname) cons
        where iTp iVar (ForallC _ cxt _) =
                  -- Check if the GADT phantom type is constrained
                  case [y | EqualP x y <- cxt, x == VarT iVar] of
                    [] -> Nothing
                    tp:_ -> Just tp
              iTp _ _ = Nothing
              genSmartConstr targs tname ((name, args), miTp) = do
                let bname = nameBase name
                genSmartConstr' targs tname (mkName $ 'i' : bname) name args miTp
              genSmartConstr' targs tname sname name args miTp = do
                varNs <- newNames args "x"
                let pats = map varP varNs
                    vars = map varE varNs
                    val = foldl appE (conE name) vars
                    sig = genSig targs tname sname args miTp
                    function = [funD sname [clause pats (normalB [|inject $val|]) []]]
                sequence $ sig ++ function
              genSig targs tname sname 0 miTp = (:[]) $ do
                hvar <- newName "h"
                fvar <- newName "f"
                avar <- newName "a"
                bvar <- newName "b"
                ivar <- newName "i"
                let targs' = init $ init $ init $ targs
                    vars = hvar:fvar:avar:bvar:(maybe [ivar] (const []) miTp)++targs'
                    h = varT hvar
                    f = varT fvar
                    a = varT avar
                    b = varT bvar
                    i = varT ivar
                    ftype = foldl appT (conT tname) (map varT targs')
                    constr = classP ''(:<:) [ftype, f]
                    typ = foldl appT (conT ''Cxt) [h, f, a, b,maybe i return miTp]
                    typeSig = forallT (map PlainTV vars) (sequence [constr]) typ
                sigD sname typeSig
              genSig _ _ _ _ _ = []
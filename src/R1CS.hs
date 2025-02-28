{-# LANGUAGE GADTs #-}

module R1CS
  ( Field
  , Poly
  , Var
  , R1C(..)
  , R1CS(..)
  , sat_r1cs
  , num_constraints
  ) where

import qualified Data.IntMap.Lazy as Map
import Control.Parallel.Strategies

import Common
import Errors
import Field
import Poly

----------------------------------------------------------------
--                Rank-1 Constraint Systems                   --
----------------------------------------------------------------

data R1C a where
  R1C :: Field a => (Poly a, Poly a, Poly a) -> R1C a

instance Show a => Show (R1C a) where
  show (R1C (aV,bV,cV)) = show aV ++ "*" ++ show bV ++ "==" ++ show cV

data R1CS a =
  R1CS { r1cs_clauses :: [R1C a]
       , r1cs_num_vars :: Int         
       , r1cs_in_vars :: [Var]
       , r1cs_out_vars :: [Var]
       , r1cs_gen_witness :: Assgn a -> Assgn a
       }
         
instance Show a => Show (R1CS a) where
  show (R1CS cs nvs ivs ovs _) = show (cs,nvs,ivs,ovs)

num_constraints :: R1CS a -> Int
num_constraints = length . r1cs_clauses

-- sat_r1c: Does witness 'w' satisfy constraint 'c'?
sat_r1c :: Field a => Assgn a -> R1C a -> Bool
sat_r1c w c
  | R1C (aV, bV, cV) <- c
  = inner aV w `mult` inner bV w == inner cV w
    where inner :: Field a => Poly a -> Assgn a -> a
          inner (Poly v) w'
            = let c0 = Map.findWithDefault zero (-1) v
              in Map.foldlWithKey (f w') c0 v

          f w' acc v_key v_val
            = (v_val `mult` Map.findWithDefault zero v_key w') `add` acc

-- sat_r1cs: Does witness 'w' satisfy constraint set 'cs'?
sat_r1cs :: Field a => Assgn a -> R1CS a -> Bool
sat_r1cs w cs = all id $ is_sat (r1cs_clauses cs)
  where is_sat cs0 = map g cs0 `using` parListChunk (chunk_sz cs0) rseq
        num_chunks = 32
        chunk_sz cs0
          = truncate $ (fromIntegral (length cs0) :: Rational) / num_chunks
        g c = if sat_r1c w c then True
              else fail_with
                   $ ErrMsg ("witness\n  " ++ show w
                              ++ "\nfailed to satisfy constraint\n  " ++ show c
                              ++ "\nin R1CS\n  " ++ show cs)


  








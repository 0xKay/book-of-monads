{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE MonoLocalBinds #-}

module Lib where

import           Control.Monad.Trans.Reader
import           Control.Monad.Trans.Class
import           Control.Monad.Base
import           Control.Monad.ST
import           Control.Monad
import           Control.Monad.IO.Unlift
import           Control.Monad.Trans.Unlift
import           Control.Monad.Trans.Control    ( control )
import           System.IO

-- Consider the monad transformer MnT, with instances
-- instance Monad m => Monad (MnT m) where
--   ...
--
-- type Mn = MnT Identity
--
-- class Monad m => MonadMn m where
--   op :: ...
--
-- instance Monad m => MonadMn m where
--   op = ...
--
-- instance Monad m => MonadMn ({MaybeT, ReaderT, StateT} m) where
--   op = ...
--
-- We need to implement every layer of the stack, i.e. For each type class,
-- given `n` different transformers, one has to implement `n` different
-- instances. $n^2$ problem.

-- Exercise 12.1 Convince yourself that a generic lifting function
-- `liftThroughReaderT :: m a -> ReaderT r m a` exists for various
-- versions of `MonadMn` instances
--
-- Skipped...

f1 :: Maybe Int
f1 = pure 5

f2 :: Int -> ReaderT String Maybe Bool
f2 x = pure (x == 0)

-- Without `lift` we operate in the Maybe Monad
-- and therefore `f2` is a compiler error
g = do
  x <- lift f1
  f2 x

newtype IOWrap a =
  IOWrap
    { runIOWrap :: IO a
    } deriving (Functor, Applicative, Monad)

newtype STWrap s a =
  STWrap
    { runSTWrap :: ST s a
    } deriving (Functor, Applicative, Monad)

instance MonadBase IOWrap IOWrap where
  liftBase = id

instance MonadBase (STWrap s) (STWrap s) where
  liftBase = id

instance (Applicative (t m), Monad (t m), MonadBase b m, MonadTrans t) =>
    MonadBase b (t m) where
  liftBase :: b a -> t m a
  liftBase = lift . liftBase

-- mplus :: Monad m => m a -> m a -> m a
-- To lift mplus, we need
-- liftedMplus :: (Monad m, MonadTrans t) => t m a -> t m a -> t m a

-- mplus' :: (MonadTrans t, Monad m, MonadPlus m) => t m a -> t m a -> t m a
-- mplus' x y = lift $ mplus (_unlift x) (_unlift y)

-- catchError :: MonadError e m => m a -> (e -> m a) -> m a
-- catchError = ...
--
-- lift `catchError` through a transformer, we need
--
-- catchError' :: t m a -> (e -> t m a) -> t m a
-- catchError' c h = lift $ catchError (unlift c) (unlift . h)

-- Exercise 12.3: Write the lifted version of `withFile` using
-- `MonadUnliftIO` from `unliftio-core`
-- withFile :: FilePath -> IOMode -> (Handle -> IO r) -> IO r
withFile' :: MonadUnliftIO m => FilePath -> IOMode -> (Handle -> m r) -> m r
withFile' fp im act = withRunInIO $ \run -> withFile fp im (run . act)

withFile'' :: MonadBaseUnlift IO m => FilePath -> IOMode -> (Handle -> m r) -> m r
withFile'' fp im act = do
  UnliftBase run <- askUnliftBase
  liftBase $ withFile fp im (run . act)

withFile''' :: MonadBaseControl IO m => FilePath -> IOMode -> (Handle -> m r) -> m r
withFile''' fp im act = control $ \run -> withFile fp im (run . act)

{-# LANGUAGE DeriveDataTypeable #-}
-- Copyright (C) 2008 JP Bernardy

-- | This module defines buffer operation on regions

module Yi.Buffer.Region 
  (
   module Yi.Region
  , swapRegionsB
  , deleteRegionB
  , replaceRegionB
  , replaceRegionClever
  , readRegionB
  , mapRegionB
  , modifyRegionB
  , modifyRegionClever
  , winRegionB
  , inclusiveRegionB
  )
where
import Data.Algorithm.Diff
import Yi.Region
import Yi.Buffer.Misc
import Yi.Prelude
import Prelude ()
import Data.List (length)

import Control.Monad.RWS.Strict (ask)

winRegionB :: BufferM Region
winRegionB = do
    w <- ask
    Just ms <- getMarks w
    tospnt <- getMarkPointB (fromMark ms)
    bospnt <- getMarkPointB (toMark ms)
    return $ mkRegion tospnt bospnt

-- | Delete an arbitrary part of the buffer
deleteRegionB :: Region -> BufferM ()
deleteRegionB r = deleteNBytes (regionDirection r) (regionEnd r ~- regionStart r) (regionStart r)

-- | Read an arbitrary part of the buffer
readRegionB :: Region -> BufferM String
readRegionB r = nelemsB' (regionEnd r ~- i) i
    where i = regionStart r

-- | Replace a region with a given string.
replaceRegionB :: Region -> String -> BufferM ()
replaceRegionB r s = do
  deleteRegionB r
  insertNAt s (regionStart r)

-- | As 'replaceRegionB', but do a minimal edition instead of deleting the whole
-- region and inserting it back.
replaceRegionClever :: Region -> String -> BufferM ()
replaceRegionClever region text' = savingExcursionB $ do
    text <- readRegionB region
    let diffs = getGroupedDiff text text'
    moveTo (regionStart region)
    forM_ diffs $ \(d,str) -> do
        case d of
            F -> deleteN $ length str
            B -> rightN $ length str
            S -> insertN str

mapRegionB :: Region -> (Char -> Char) -> BufferM ()
mapRegionB r f = do
  text <- readRegionB r
  replaceRegionB r (fmap f text)

-- | Swap the content of two Regions
swapRegionsB :: Region -> Region -> BufferM ()  
swapRegionsB r r'
    | regionStart r > regionStart r' = swapRegionsB r' r
    | otherwise = do w0 <- readRegionB r
                     w1 <- readRegionB r'
                     replaceRegionB r' w0
                     replaceRegionB r  w1

-- Transform a replace into a modify.
replToMod replace = \transform region -> replace region =<< transform <$> readRegionB region

-- | Modifies the given region according to the given
-- string transformation function
modifyRegionB :: (String -> String)
                 -- ^ The string modification function
              -> Region
                 -- ^ The region to modify
              -> BufferM ()
modifyRegionB = replToMod replaceRegionB

    
-- | As 'modifyRegionB', but do a minimal edition instead of deleting the whole
-- region and inserting it back.
modifyRegionClever :: (String -> [Char]) -> Region -> BufferM ()
modifyRegionClever =  replToMod replaceRegionClever

-- | Extend the right bound of a region to include it.
inclusiveRegionB :: Region -> BufferM Region
inclusiveRegionB r =
          if regionStart r <= regionEnd r
              then mkRegion (regionStart r) <$> pointAfter (regionEnd r)
              else mkRegion <$> pointAfter (regionStart r) <*> pure (regionEnd r)
    where pointAfter p = pointAt $ do 
                           moveTo p
                           rightB

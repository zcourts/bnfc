module TestUtils
    ( makeShellyTest, assertFileExists, assertEqual, assertFailure
    , makeTestSuite
    , pathToString
    , findFileRegex
    , Test(..) ) where

-- base
import Control.Exception (handle, throwIO, SomeException)
import Prelude hiding (FilePath)
import Text.Regex.Posix

-- text
import qualified Data.Text as T

-- system-filepath
import Filesystem.Path.CurrentOS (encodeString, toText, encode)

-- shelly
import Shelly

-- htf
import Test.Framework (assertEqualPretty_)
import Test.Framework.Location (unknownLocation)
import Test.Framework.Pretty (Pretty(..), text)
import qualified Test.Framework.TestManager as HTF
import Test.Framework.TestTypes

-- hunit
import qualified Test.HUnit as HUnit

-- | Replate the makeTestSuite function from HTF. This one returns a Test
-- object instead of a TestSuite which makes it easier to mix single test
-- and test suites in ohter test suites
makeTestSuite :: TestID -> [Test] -> Test
makeTestSuite id = HTF.testSuiteAsTest . HTF.makeTestSuite id

-- Lift HTF's version of assertEqual in Sh
assertEqual :: (Eq a, Pretty a) => a -> a -> Sh ()
assertEqual a b = liftIO $ assertEqualPretty_ unknownLocation a b

-- | Pretty instance for Text (to use with assertEquals)
instance Pretty T.Text where
  pretty = text . T.unpack

-- Shortcut function to create a (black box) test from a shelly script
makeShellyTest :: TestID -> Sh () -> Test
makeShellyTest label =
    HTF.makeBlackBoxTest label . handle fixException . shelly . verbosely
  where
    fixException (ReThrownException x _) = throwIO (x::SomeException)

-- A (Shelly) assertion to check the existense of a file
assertFileExists :: FilePath -> Sh ()
assertFileExists p = test_f p >>= liftIO . HUnit.assertBool errorMessage
  where errorMessage = "Can't find file " ++ encodeString p

-- | Lift HUnit's assertFailure
assertFailure :: String -> Sh ()
assertFailure = liftIO . HUnit.assertFailure

-- | A PrintfArg instance of FilePath to use filepaths in strings (e.g. names
-- of tests). Allows you to do things like:
-- printf "testing %s" (path :: FilePath)
--
-- !! Commented for now as it is only possible with ghc-7.8.3
-- instance Text.Printf.PrintfArg FilePath where
--   formatArg = formatArg . either T.unpack T.unpack . Filesystem.Path.CurrentOS.toText

-- | Convert a FilePath to a string
pathToString = either T.unpack T.unpack . toText

-- | Find a file given a regular expression.
-- Will fail if there is not exactly one file matching
findFileRegex :: String -> Sh FilePath
findFileRegex r = do
    fs <- findWhen (return . (=~ r) . encode) "."
    when (length fs < 1) $ assertFailure "File not found"
    when (length fs > 1) $ assertFailure "Too many files"
    return (head fs)

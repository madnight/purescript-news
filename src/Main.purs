module Main
( main
) where

import Control.Alt ((<|>))
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Ref (REF)
import Cowlaser.Route (dir, root, withRouting)
import Cowlaser.Serve (nodeHandler)
import Data.Int (fromString)
import News.Feed (cache, EntryList(..), Feed, limit)
import News.Feed.RSS (rss)
import News.Page.Home (home)
import News.Page.JSON (json)
import News.Page.NotFound (notFound)
import News.Prelude
import Node.HTTP (createServer, listen)
import Node.Process (PROCESS, exit, lookupEnv)

main :: forall eff. Eff (http :: HTTP, ref :: REF, process :: PROCESS | eff) Unit
main = do
  mPort <- lookupEnv "PURESCRIPT_NEWS_PORT"
  port <- maybe (exit 1) pure (mPort >>= fromString)

  reddit'        <- cache $ limit 10 $ reddit
  twitter'       <- pure twitter
  google'        <- cache $ limit 10 $ google
  stackOverflow' <- cache $ limit 10 $ stackOverflow
  releases'      <- cache $ limit 10 $ releases
  let feeds = reddit' : twitter' : google' : stackOverflow' : releases' : Nil

  server <- createServer $ nodeHandler (main' feeds)
  listen server port (pure unit)

  where reddit =
          { title: "Reddit"
          , url: "https://www.reddit.com/r/purescript"
          , fetch: rss "https://www.reddit.com/r/purescript.rss"
          }
        twitter =
          { title: "Twitter"
          , url: "https://twitter.com/search?q=%23purescript"
          , fetch: pure (TwitterEntryList "769970282056605700")
          }
        google =
          { title: "Google Groups"
          , url: "https://groups.google.com/group/purescript"
          , fetch: rss "https://groups.google.com/forum/feed/purescript/topics/atom.xml?num=15"
          }
        stackOverflow =
          { title: "Stack Overflow"
          , url: "https://stackoverflow.com/questions/tagged/purescript"
          , fetch: rss "https://stackoverflow.com/feeds/tag?tagnames=purescript&sort=newest"
          }
        releases =
          { title: "Releases"
          , url: "https://github.com/purescript/purescript/releases"
          , fetch: rss "https://github.com/purescript/purescript/releases.atom"
          }

main'
  :: forall eff m
   . (MonadReader (Request eff) m)
  => List (Feed (http :: HTTP | eff))
  -> m (Response eff)
main' feeds = withRouting go
  where go =     (root *> home feeds)
             <|> (dir "api" $ dir "v1" $ dir "feeds" $ root *> json feeds)
             <|> (notFound)

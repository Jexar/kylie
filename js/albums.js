/* The archive, one entry per game date — the things only you know.

   The frame filenames are NOT listed here. They're read from the photos/
   folder by build-photos.bat, which writes js/photos.js for you.

   To add a game:
     1. make photos/2026-11-04-team-name/ and put that game's frames in it
     2. copy an entry below and set date, title, sport, venue, note and dir
     3. double-click build-photos.bat

   Frames appear in filename order. `cover` picks the card image for the Work
   page — leave it "" to use the first frame.

   Order of entries doesn't matter — the Work page sorts by date, newest first.
   An album whose folder is empty or missing shows as a placeholder card and
   isn't clickable, so a date can go up before the edit is finished. */

window.ALBUMS = [

  {
    slug:  "parrish-bulls-2026-09-11",
    date:  "2026-09-11",
    title: "Parrish Bulls vs George Jenkins Eagles",
    sport: "Hockey",
    venue: "Polk Athletic Complex, Lakeland",
    note:  "Final Score: Bulls 3-1 Eagles",
    dir:   "photos/2026-09-11-parrish-bulls",
    cover: "DSC08223_VSCO.JPG"
  }

];

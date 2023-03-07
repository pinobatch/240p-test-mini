Checklist before release
========================

Day 1
-----
First test all six NES builds on NES, the GB build on all GB models,
and the GBA build on a GBA.  Start with Credits and touch every
test at least once.  Make screenshots of new features and alt text
for those screenshots. Sleep on it.

Day 2
-----
Open relevant files and forums:

    mousepad nes/CHANGES.txt gameboy/CHANGES.txt gba/CHANGES.txt \
        makefile nes/makefile gameboy/makefile nes/src/helppages.txt \
        gameboy/src/helppages.txt gba/src/helppages.txt \
        common/docs/junkerhq/index.html
    xdg-open private/
    firefox 'common/docs/junkerhq/index.html' \
        'https://github.com/pinobatch/240p-test-mini/releases' \
        'https://forums.nesdev.org/viewtopic.php?f=22&t=13394' \
        'https://gbdev.gg8.se/forums/viewtopic.php?id=542' \
        'https://forum.gbadev.net/topic/22-160p-test-suite' \
        'https://www.patreon.com/' 'https://peoplemaking.games/' \
        'https://www.retroveteran.com/masthead/' &
    git log --oneline

1. `CHANGES.txt` (3): Ensure version and release date are updated,
   and all common changes have the same wording
2. Make a common change highlights list for the GitHub release,
   based on this version's `CHANGES.txt` files, and split into
   user-visible and behind-the-scenes changes
3. `makefile` (3): Ensure version is updated
4. `helppages.txt` (3): Update release year and patron list
5. `make all` to ensure all versions are built, including the
   sometimes neglected alternate mapper NES versions
6. Test zipfile for completeness

        rm -r build
        make dist && mkdir build && cd build
        unzip ../240p-test-mini-0.xx.zip
        make -j2 all

7. `git status` and correct anything out of the ordinary
8. `git add -u && git commit`
9. `git tag v0.xx && git push && git push --tags`
10. `make clean && make -j2 dist` to put the new tag in credits
11. On GitHub, draft a new release titled
    `240p Test Suite (NES, GB, GBA) v0.xx`
    and attach six .nes files, one .nsf, one .gb, and one .gba,
    along with the screenshots
12. In `junkerhq/index.html`, update file sizes and release year.
    Upload to junkerhq per private steps, then verify at
    <https://junkerhq.net/240pTestSuite/PinoBatch/>
13. Post highlights and link to GitHub release page to NESdev topic
    and Patreon, attaching screenshots and ROM and source zipfile
14. Post platform-relevant highlights, link to GitHub release, and
    link to NESdev attachment on gbdev.gg8.se and forum.gbadev.net
15. Mail highlights and link to GitHub release page to the
    address shown at <https://www.retroveteran.com/masthead/>
16. Post highlights, screenshots, and link to GitHub release to
    Mastodon

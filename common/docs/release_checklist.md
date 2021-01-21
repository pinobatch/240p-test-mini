Checklist before release

First open relevant files and forums:

    mousepad nes/CHANGES.txt gameboy/CHANGES.txt gba/CHANGES.txt \
        makefile nes/makefile gameboy/makefile nes/src/helppages.txt \
        gameboy/src/helppages.txt gba/src/helppages.txt &
    firefox 'https://github.com/pinobatch/240p-test-mini/releases' \
        'https://forums.nesdev.com/viewtopic.php?f=22&t=13394' \
        'https://gbdev.gg8.se/forums/viewtopic.php?id=542' \
        'https://forum.gbadev.org/viewtopic.php?f=6&t=18168' &

1. `CHANGES.txt` (3): Ensure version and release date are updated,
   and all common changes have the same wording
2. Make a common change highlights list for the GitHub release,
   based on this version's `CHANGES.txt` files, and split into
   user-visible and behind-the-scenes changes
3. `makefile` (3): Ensure version is updated
4. `helppages.txt` (3): Ensure version, release date, and patron list
   are updated
5. `make all` to ensure all versions are built, including the
   sometimes neglected NES-BNROM version
6. Test zipfile for completeness

        rm -r build
        make dist && mkdir build && cd build
        unzip ../240p-test-mini-0.xx.zip
        make -j2 all

7. Test major functionality on NES PowerPak, EverDrive GB X5, and
   GBA Movie Player, starting with Credits and touching every test
   at least once
8. `git status` and correct anything out of the ordinary
9. `git add -u && git commit`
10. `git tag v0.xx && git push && git push --tags`
11. On GitHub, draft a new release titled
    "240p Test Suite (NES, GB, and GBA) v0.xx`
    and attach two .nes files, one .nsf, one .gb, one .gba
12. Post highlights and link to GitHub release page to NESdev topic,
    attaching ROM and source zipfile
13. Post platform-relevant highlights, link to GitHub release, and
    link to NESdev attachment on gbdev.gg8.se and forum.gbadev.org
14. Mail highlights and link to GitHub release page to the
    address shown at <https://pdroms.de/submit-news>

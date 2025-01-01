Saint Seiya Deckbuilding PDF generator
======================================

To generate a 4x4 PDF with the English translation:
`./saint_seiya.sh -t 4`

English translation input files by pve159 from:
https://boardgamegeek.com/thread/3044902/english-translation-correct-version

---

The script basically:
1. Crop all the images to remove the white margins.
2. Split the images in 9 to get the individual cards.
3. Remove all the blank images.
4. Compose the images back in a tiled page (1, 2x2 or 3x3).
5. Generate a compressed PDF (~10MB).

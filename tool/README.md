## Quran data (`build_quran.dart`)

Run from the project root: `C:\src\flutter\bin\dart.bat run tool/build_quran.dart`.
Raw API responses are cached in `tool/quran_cache/` (git-ignored); the script downloads
any missing edition, otherwise it runs fully offline. It writes `assets/quran/` and fails
(non-zero exit) if any self-check fails (114 surahs, 6236 ayahs, per-surah counts equal
across editions, no empty fields, search.txt 6236 lines, basmala only at 1:1).

Never edit the generated files by hand. Text transforms done by the script: remove the
leading BOM (U+FEFF) present in 1:1; remove the basmala prefix that the API prepends to
ayah 1 of surahs 2-8 and 10-114 (the app shows it as a header); for `search.txt` only,
strip diacritics/Quranic marks and normalize أ إ آ ٱ to ا.

| Data | Source / URL | Edition |
|---|---|---|
| Arabic text (`ar`) | https://api.alquran.cloud/v1/quran/quran-uthmani | Tanzil Uthmani |
| Search text (`search.txt`) | https://api.alquran.cloud/v1/quran/quran-simple-clean | Tanzil Simple Clean (Uthmani spellings like ٱلصَّلَوٰةَ do not strip to الصلاة) |
| Tafsir (`tafsir`) | https://api.alquran.cloud/v1/quran/ar.muyassar | التفسير الميسر, King Fahd Glorious Quran Printing Complex |
| Translation (`en`) | https://api.alquran.cloud/v1/quran/en.sahih | Saheeh International |
| Font `Quran` | https://github.com/aliftype/amiri/releases/download/1.003/Amiri-1.003.zip | Amiri Quran 1.003 (`assets/fonts/AmiriQuran.ttf`) |

Licenses / attribution:
- **Tanzil Quran text**: CC BY 3.0 with extra terms (https://tanzil.net/docs/text_license):
  verbatim copies only, no changes; the app must clearly credit "Tanzil Project" and link
  to tanzil.net; the notice must accompany derived files (`assets/quran/TANZIL-NOTICE.txt`).
- **Saheeh International**: copyrighted translation (Saheeh International / Abul-Qasim
  Publishing House). Tanzil's translation page states its translations are for
  non-commercial use only; commercial use needs permission from the publisher.
- **Tafsir al-Muyassar**: published by the King Fahd Complex; no explicit redistribution
  license found via alquran.cloud. Free non-commercial use with attribution is the common
  practice, but this is not verified — credit the Complex and check before commercial release.
- **Amiri Quran font**: SIL Open Font License 1.1 (`assets/fonts/AmiriQuran-OFL.txt`).
- api.alquran.cloud (Islamic Network) is only the delivery channel; credit it as well.

## Azkar data (`build_azkar.dart`)

Run from the project root: `C:\src\flutter\bin\dart.bat run tool/build_azkar.dart`
(add `--list` to print every item for review). Input: `tool/azkar_selection.json`.
Output: `assets/azkar.json` (minified). Raw datasets are cached in `tool/hadith_cache/`
(git-ignored); missing files are downloaded, otherwise it runs offline.

Scope rule: every item is from Sahih al-Bukhari or Sahih Muslim only.

How text is produced: no Arabic or English is typed by hand. Each item names a hadith
and start/end markers; the script cuts the dhikr (and optional `note_ar`/`note_en`
context) out of the dataset text and asserts the result is a verbatim substring of that
hadith. Arabic markers match ignoring tashkeel, hamza/alef forms, ta marbuta, punctuation;
English markers are exact. `en_full: true` ships the whole English hadith when the
translation can't be cut cleanly. A `count` > 1 requires a `count_proof_ar` phrase that
must occur in the hadith. Typos in the translation (e.g. "entere d") are kept verbatim.

| Data | Source / URL | License |
|---|---|---|
| Bukhari Arabic (with tashkeel) | https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari.json | Unlicense (public domain) |
| Bukhari English (Muhsin Khan) | https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-bukhari.json | Unlicense (dataset) |
| Muslim Arabic (with tashkeel) | https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-muslim.json | Unlicense (public domain) |
| Muslim English (Abdul Hamid Siddiqui) | https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-muslim.json | Unlicense (dataset) |

The dataset is released under the Unlicense (https://github.com/fawazahmed0/hadith-api).
The English translations themselves are the classic Muhsin Khan (Bukhari) and Siddiqui
(Muslim) translations as distributed on sunnah.com; their own copyright status is not
stated by the dataset — credit the translators.

Numbering (fields per item):
- `dataset_number` (selection file `number`): the dataset's `hadithnumber`.
- `number`: sunnah.com reference number (Abd al-Baqi for Muslim) as an integer.
- `ref`: the same with sunnah.com's narration letter, e.g. `2723c`.
- Bukhari: dataset numbering == sunnah.com numbering (`hadithnumber == arabicnumber`).
- Muslim: dataset `hadithnumber` is a sequential count (e.g. 6843) and does NOT match
  sunnah.com; the dataset's `arabicnumber` does (e.g. "2692"; "2723.03" = sunnah.com
  2723c). The script maps it. Checked on 2026-11-12: all 66 items' Arabic dhikr text was
  found on the sunnah.com page for the emitted `ref` (e.g. https://sunnah.com/bukhari:6306,
  https://sunnah.com/muslim:2723c).

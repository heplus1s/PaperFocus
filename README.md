# PaperFocus

English | [中文](README.zh-CN.md)

## Overview

PaperFocus is an application for focused academic reading. It keeps a local library of papers, opens PDFs in the app, and includes a focus timer. It is for people who read research literature and want the papers, the reading session, and the timer kept together.

## Features

- A local paper library on the device.
- PDF reading inside the app.
- A focus timer for reading sessions.
- Optional paper summaries and translation. You enter the service credentials in Settings. This repository does not contain those credentials.

## Requirements

The PaperFocus application target in `PaperFocus.xcodeproj` declares these deployment targets:

- macOS 15.7 or later
- iOS 26.2 or later, for iPhone and iPad
- visionOS 26.2 or later

## Build and run

Open `PaperFocus.xcodeproj` in Xcode. Select the PaperFocus scheme and run it on the destination you need.

## Library and import

Import supports these sources:

- A Zotero library
- An EndNote XML export
- A PaperFocus library, either the app’s own store or a `paperfocus.library` file
- One or more PDF files
- A folder of PDFs

A file that is not one of these formats is not imported.

### Zotero on macOS

On macOS, PaperFocus looks for a local Zotero library before asking you to browse. It checks the default data directory (`~/Zotero`), `~/Documents/Zotero`, `~/Library/Application Support/Zotero`, and the data directory recorded in the Zotero profile. A folder is used only when it contains `zotero.sqlite` with Zotero’s expected tables.

- If one valid library is found, it is offered for linking. When **Use the local Zotero library** is on, which is the default, and no library is linked yet, that single library is linked at launch instead of starting a separate empty catalog.
- If several libraries are found, you choose one. PaperFocus does not pick among them automatically.
- If none is found, or you want a different location, use the system file picker. The chosen location is checked in the same way.

You can also link a Zotero account with an API key that you create on the Zotero website. The key is stored only in the app’s settings. Browser sign-in is not included.

**Use only the Zotero library** is off by default. When it is on, the library list shows Zotero items only. Items already in the in-app library are not deleted. They appear again when the option is turned off.

**Copy attachments on import** is off by default. When it is off, PaperFocus opens the original files, including files in Zotero’s storage, and does not make a copy. When it is on, import may copy attachments into the app.

### iPhone and iPad

On iPhone and iPad, PaperFocus does not search a Mac data directory. Choose a Zotero data folder, or other files, in the Files app. That includes On My iPhone, On My iPad, and other locations you grant. You can also enter a Zotero API key.

PDFs are opened from those original locations. They are not copied into the app. The document picker does not take a copy, and the app does not fall back to storing a PDF in its own container.

### EndNote

EndNote import reads an EndNote XML export. An EndNote library package (`.enl`) is not imported. Export XML from EndNote, then choose that file.

## Settings and API keys

Paper summaries, translation, and Zotero account access use credentials that you enter in Settings. Those values remain on the device. This repository does not contain API keys or other secrets.

## License

The source code in this repository is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and share the software for noncommercial purposes. Commercial use by third parties is not allowed without prior permission. To request a commercial license, open an issue in this repository.

The copyright holders, The PaperFocus authors, reserve the right to license and distribute PaperFocus under separate commercial terms, including paid publication of the application. The English LICENSE file is the legal text of the noncommercial license.

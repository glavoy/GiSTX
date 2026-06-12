# GiSTX — burkinafaso branch

This branch supports the **R21 Negative study** running across two countries: **Uganda** and **Burkina Faso**. It is bilingual (English / French) and connects to two different servers depending on the country selected in Settings.

| Setting | Uganda | Burkina Faso |
|---|---|---|
| Language | English | French |
| Protocol | FTP | SFTP |
| Server | 0f7a55b.netsolhost.com:21 | ftp.crundata.net:2220 |

See the **main** branch for the single-country English-only version.

---

## Overview

GiSTX is a cross-platform offline survey and data collection application built with Flutter. It enables researchers and data collectors to administer XML-based questionnaires in field settings without requiring internet connectivity.

## Key Features

- **Offline-First Architecture**: All data is stored locally in SQLite database, perfect for field research in remote locations
- **XML-Based Surveys**: Define questionnaires using simple XML files with support for multiple question types (text, radio, checkbox, date, etc.)
- **Hierarchical Data Collection**: Support for parent-child survey relationships (e.g., household enrollment followed by household member surveys)
- **Auto-Repeat Surveys**: Automatically loop through child surveys based on count fields (e.g., survey N household members)
- **Dynamic ID Generation**: Configurable unique ID generation with custom prefixes and field-based composition
- **Smart Navigation**: Intuitive record selection and modification with descriptive display fields
- **Data Validation**: Built-in support for numeric ranges, date ranges, logic checks, and unique value validation
- **Dynamic Text Replacement**: Insert previously answered values into question text using `[[fieldname]]` placeholders
- **Auto-Increment Fields**: Automatic line number generation for repeated records

## Use Cases

- Household surveys with multiple members
- Clinical research data collection
- Field studies in areas with limited connectivity
- Any scenario requiring structured data collection with parent-child relationships

## Technical Stack

- **Framework**: Flutter/Dart
- **Database**: SQLite with automatic schema synchronization
- **Platforms**: Windows, macOS, Linux, Android, iOS
- **Survey Definition**: XML

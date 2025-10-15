## `violation` Table (created during EA scraping build)

Primary Fields:
├── id (UUID) - Primary key
├── case_id (FK) - Links to parent Case record
├── violation_sequence (Integer) - Order within case (1, 2, 3...)
├── case_reference (String) - "SW/A/2010/2051079/01" (unique per violation)
├── individual_fine (Decimal) - £2,750 (fine for this specific violation)
├── offence_description (String) - Violation text
├── legal_act (String) - Act for this specific violation
├── legal_section (String) - Section for this specific violation
└── created_at/updated_at (DateTime) - Standard timestamps


## `breaches` Table (created during HSE scraping build)

**Purpose**: Specific legislation breaches associated with cases (normalized from breach text).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|

| `id` | `uuid` | PRIMARY KEY, NOT NULL | Breach unique identifier |
| `case_id` | `uuid` | NOT NULL, FK → cases.id | Associated case |
| `breach_description` | `text` | NULLABLE | Description of the breach |
| `legislation_reference` | `text` | NULLABLE | Specific legislation reference |
| `legislation_type` | `text` | NULLABLE | Type of legislation |
| `inserted_at` | `timestamp` | NOT NULL | Record creation time |

## `offences` Table [combining `violation` and `breaches`]

**Purpose**: Register of legislative breaches and violations

| Column | Type | Constraints | Description | Example |
|--------|------|-------------|-------------|---------|

├── `id` | `uuid` | PRIMARY KEY, NOT NULL | Offence unique identifier |
├── `case_id` | `uuid` | FK → cases.id | NULLABLE | One to Many relationship with associated case(s) |
├── `notice_id` | `uuid` | FK → notices.id | NULLABLE | One to many relationship with associated notice(s) |
├── `legislation_id` | `uuid` | FK → legislation.id | One offence has one legislation |
├── `offence_reference` | `text` | NULLABLE | EAs offence ref | Example: "SW/A/2010/2051079/01" (unique per offence) |
├── `offence_description` | `text` | NULLABLE | Description of the breach |
├── `legislation_part` | `text` | --- | The section or regulation |
├── `fine` | `decimal` | --- | Fine for this specific offence | £2,750 |
├── `created_at` | `DateTime` | --- | Standard timestamp |
└── `updated_at` | `DateTime` | --- | Standard timestamp |

## `legislation` Table

| Column | Type | Constraints | Description | Example |
|--------|------|-------------|-------------|---------|

├── `id` | `uuid` | PRIMARY KEY, NOT NULL | Legislation unique identifier |
├── `case_id` | `uuid` | FK → cases.id | NULLABLE | One to Many relationship with associated case(s) |
├── `notice_id` | `uuid` | FK → notices.id | NULLABLE | One to many relationship with associated notice(s) |
├── `offence_id` | `uuid` | FK → notices.id | NULLABLE | One to many relationship with associated offence(s) |
├── `legislation_title` | `text` |--- | Legislation title | **Health and Safety at Work etc. Act** 1974 33 |
├── `legislation_year` | `number` | --- | Legislation year | Health and Safety at Work etc. Act **1974** 33 |
├── `legislation_number` | `number` | --- | Legislation number | Health and Safety at Work etc. Act 1974 **33** |
├── `legislation_type` | `text` | NULLABLE | Type of legislation | **Act** or Regulation or Order |
├── `created_at` | DateTime | --- | Standard timestamp |
└── `updated_at` | DateTime | --- | Standard timestamp |

**MAPPING**

| Offences | Breaches | Violations |
|----------|----------|------------|

| id | id | id |
| case_id | case_id | case_id |
| notice_id | --- | --- |
├── `offence_reference` | --- | case_reference |
├── `offence_description` | breach_description | offence_description |
├── `fine` | --- | individual_fine |
├── `created_at` | inserted_at | inserted_at |
└── `updated_at` | --- | ---



| Legislation | Breaches | Violations |
|-------------|----------|------------|

├── `legislation_title` | --- | legal_act |
├── `legislation_year` | --- | --- |
├── `legislation_number` | --- | --- |
├── `legislation_part` | --- | legal_section |
├── `legislation_type` | legislation_type | --- |

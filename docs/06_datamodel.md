# Datamodel

## Tabellen

### users

- id
- email
- password_hash
- display_name
- role
- created_at
- updated_at
- deleted_at

### courses

- id
- slug
- title
- description
- image_url
- status
- sort_order
- created_by
- created_at
- updated_at
- deleted_at

### chapters

- id
- course_id
- slug
- title
- subtitle
- description
- xp
- status
- sort_order
- published_at
- created_by
- created_at
- updated_at
- deleted_at

### blocks

- id
- chapter_id
- type
- title
- content_json
- xp
- required
- sort_order
- status
- created_at
- updated_at
- deleted_at

### content_versions

- id
- entity_type
- entity_id
- version_number
- snapshot_json
- created_by
- created_at

### groups

- id
- name
- course_id
- invite_code
- owner_user_id
- status
- created_at
- updated_at

### group_members

- id
- group_id
- user_id
- role
- joined_at

### user_progress

- id
- user_id
- course_id
- chapter_id
- block_id
- status
- completed_at
- response_required
- created_at
- updated_at

### block_responses

- id
- user_id
- block_id
- group_id
- response_json
- visibility
- created_at
- updated_at
- deleted_at

### discoveries

- id
- user_id
- group_id
- block_id
- type
- body
- media_asset_id
- visibility
- status
- created_at
- updated_at
- deleted_at

### discovery_comments

- id
- discovery_id
- user_id
- body
- status
- created_at
- updated_at
- deleted_at

### discovery_reactions

- id
- discovery_id
- user_id
- reaction_type
- created_at

### questions

- id
- user_id
- group_id
- block_id
- title
- body
- status
- is_pinned
- created_at
- updated_at
- deleted_at

### question_answers

- id
- question_id
- user_id
- body
- is_official
- created_at
- updated_at
- deleted_at

### question_votes

- id
- question_id
- user_id
- created_at

### xp_events

- id
- user_id
- event_type
- source_type
- source_id
- xp
- created_at

### badges

- id
- slug
- name
- description
- icon
- rule_json
- status
- created_at
- updated_at

### user_badges

- id
- user_id
- badge_id
- awarded_at

### media_assets

- id
- owner_user_id
- storage_provider
- bucket
- object_key
- public_url
- mime_type
- file_size
- width
- height
- duration_seconds
- alt_text
- created_at
- deleted_at

## Indexen

Aanbevolen:
- courses(status, sort_order)
- chapters(course_id, status, sort_order)
- blocks(chapter_id, status, sort_order)
- group_members(group_id, user_id)
- discoveries(group_id, block_id, status)
- questions(group_id, block_id, status)
- user_progress(user_id, chapter_id)
- xp_events(user_id, source_type, source_id)


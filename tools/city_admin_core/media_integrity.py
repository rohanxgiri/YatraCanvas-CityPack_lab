"""Local media validation. Never alters SQLite or fetches remote media."""
from copy import deepcopy
from pathlib import Path


def inspect_manifest(manifest: dict, root: Path, *, prune_optional: bool = False):
    effective = deepcopy(manifest)
    report = {'missing_primary': [], 'missing_gallery': [], 'metadata_errors': [],
              'removed_gallery_items': 0}

    def inspect(place_id, item, role):
        missing = []
        for key in ('local_path', 'thumbnail_path'):
            value = item.get(key)
            if key == 'local_path' and not value:
                missing.append(f'{place_id}: {role} has no local_path')
            elif value:
                path = (root / value).resolve()
                if not path.is_relative_to(root.resolve()) or not path.is_file():
                    missing.append(f'{place_id}: {value}')
        report['missing_primary' if role == 'primary' else 'missing_gallery'].extend(missing)
        errors = []
        if str(item.get('license') or '').strip().lower() in ('', 'unknown', 'unverified'):
            errors.append('license')
        if not item.get('author') and not item.get('attribution'):
            errors.append('author/attribution')
        if errors and not (missing and role == 'gallery' and prune_optional):
            report['metadata_errors'].append(f'{place_id}: {role} missing {", ".join(errors)}')
        return missing

    for place_id, entry in effective.items():
        if not isinstance(entry, dict):
            raise ValueError(f'{place_id}: invalid image manifest record')
        if entry.get('primary'):
            inspect(place_id, entry['primary'], 'primary')
        kept = []
        for item in entry.get('gallery') or []:
            missing = inspect(place_id, item, 'gallery')
            if missing and prune_optional:
                report['removed_gallery_items'] += 1
            else:
                kept.append(item)
        entry['gallery'] = kept
    return effective, report

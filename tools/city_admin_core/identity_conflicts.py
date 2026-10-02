"""Stable source member identities used by the desktop collision queue."""
import hashlib


def member_id(candidate):
    identifiers = sorted({f'{source}:{identifier}' for source, values in
                          (candidate.get('external_ids') or {}).items() for identifier in values})
    identity = '\n'.join(identifiers) if identifiers else f"{candidate['name']}|{float(candidate['latitude'])}|{float(candidate['longitude'])}"
    return hashlib.sha256(identity.encode('utf-8')).hexdigest()[:16]


def reconcile(candidates, records, published_ids, changed):
    groups = {}
    for candidate in candidates:
        groups.setdefault(candidate['canonical_id'], []).append(candidate)
    effective, blockers = {}, []
    for identifier, members in groups.items():
        if len(members) == 1:
            effective[identifier] = members[0]
            continue
        record = records.get(identifier)
        identities = {member_id(member): member for member in members}
        if (identifier in published_ids or not record or record.get('action') not in ('merge', 'separate', 'exclude')
                or len(identities) != len(members) or set(record.get('members') or {}) != set(identities)):
            blockers.append(f'Unresolved canonical identity conflict: {identifier}')
            continue
        if any(changed(record['members'][key], member) for key, member in identities.items()):
            blockers.append(f'Changed since conflict resolution: {identifier}')
            continue
        if not record.get('author') or not record.get('notes') or not record.get('decided_at'):
            blockers.append(f'Conflict resolution has no curator evidence: {identifier}')
            continue
        if record['action'] == 'merge':
            survivor = identities.get(record.get('survivor'))
            if survivor is None:
                blockers.append(f'Conflict survivor is missing: {identifier}')
            else:
                effective[identifier] = survivor
        elif record['action'] == 'separate':
            for key, member in identities.items():
                new_id = f'{identifier}__{key}'
                if new_id in groups or new_id in published_ids or new_id in effective:
                    blockers.append(f'Resolved identity collides: {new_id}')
                else:
                    effective[new_id] = {**member, 'canonical_id': new_id}
    return effective, blockers

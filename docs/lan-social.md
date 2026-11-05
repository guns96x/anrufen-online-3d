# Durable LAN/Tailscale game session

This module implements social features confirmed in original Anrufen UI records:
chat (10004), player trade (10016), friends/party/guild (10034), mail (10047),
guild creation (10055), guild announcement (10056), bounties (10038),
consignment (10072) and shared gameplay. Capacities, costs and combat tuning
are provisional, not full original protocol or balance fidelity.

It is a **trusted LAN/Tailscale session**, not a public account/authentication
service. The host owns state and admits a bounded nickname plus a random
256-bit device token. It hashes the token and maps the transport sender to a
stable server account; payloads cannot select another account. Requests
cannot upload currency, inventory, a chosen peer ID or an offline character.
Each newly created account receives a separate online profile: 100 copper,
3 health potions (30016), 2 mana potions (30645), 32 bag slots. These items and
currency do not overwrite or merge with the offline Player profile.

`user://lan_identity.token` preserves device identity; the server stores hashes
and stable accounts in `user://lan_server_v1.json`. Atomic tmp/bak replacement
preserves the previous checkpoint. Reconnect restores online profiles, mail,
contacts, groups, guilds, consignments and bounties without new starter money.
Social/economic requests are committed before publishing; a failed commit rolls
back the action. Continuous combat checkpoints every two seconds. A failed
background checkpoint freezes the world. A crash can lose at most the latest
uncommitted combat interval. Pending player trades are cancelled on restart.

Each client displays server-owned movement, creatures, combat and its private
profile; menus dispatch intent to the host. ServerGameSession validates shop,
bank, craft and NPC quest distance and runs inventory/quest/pet rules. Joining
suspends the offline character; disconnect restores its stats, journal/location.
There is no offline inventory import, public matchmaking, SMS recovery or mail
attachment implementation. Token identity is for trusted LAN/Tailscale peers;
use Tailscale transport for remote play. This is not an internet account service.

## NetworkManager

`start_server(port=7777)`, `start_client(ip,port)`, `disconnect_session()` and
`request(action,payload)` are the integration API. `local_player_data.name` is
read for the nickname. No other uploaded profile fields are read.

Signals: `connected_ok()`, `connection_err()`, `state_updated(snapshot)`,
`notice(text)`, compatibility `player_joined(id,data)` and `player_left(id)`.
Read `social_snapshot`; `players` is only an ID -> public name dictionary.
Only authority peer 1 can send snapshots/notices. Incoming actions are capped
at 20 per peer per second, 40-character action names and 8192 encoded payload
bytes. All actions are validated again in pure `SocialState` logic.

| Action | Payload |
|---|---|
| chat | channel: global/party/guild/whisper, text, target for whisper |
| friend_request / friend_accept / friend_remove | target: peer ID |
| block / unblock | target: peer ID |
| party_invite / party_kick | target: peer ID; leader only |
| party_accept | party_id: invitation ID |
| party_leave | empty |
| guild_create | name: 2–24 characters; costs 50 session copper |
| guild_invite / guild_kick | target: peer ID; leader only |
| guild_accept | guild_id: invitation ID |
| guild_leave | empty |
| guild_declaration | text: 0–500 chars; current leader only |
| mail_send | target, subject (1–60 chars), body (1–1000 chars) |
| mail_read / mail_delete | mail_id; recipient only |
| trade_request | target |
| trade_accept / trade_confirm / trade_cancel | trade_id |
| trade_offer | trade_id, copper >= 0, items: {"source_item_id": count} |
| auction_list | item_id, count, price; reserves actual stock |
| auction_buy / auction_cancel | listing_id; cancellation seller only |
| bounty_create | target, reward, min_level 1–100, required kills 1–10 |
| bounty_accept / bounty_cancel | bounty_id; cancellation issuer before acceptance |
| game_* | ServerGameSession commands; no arbitrary profile upload |

A party has up to 4 members; a guild up to 20. Explicitly leaving transfers
leadership to the first remaining member, or removes the empty group. Disconnect
keeps group membership and accounts, while cancelling unfinished trades. Mail has
no item/currency attachments and each inbox holds up to 50 letters. Chat retains
the most recent 100 messages, each up to 300 characters. Private chat recipients
are recorded at send time. Snapshots expose only messages delivered to that peer
and only its own inbox, friend requests, blocked list and session profile.

## Snapshot shape

- `own_id`, `name`, `profile` (private session profile).
- `onlineplayers` and alias `players`: array of `{id: int, name: String}`.
- `friends`, `friendrequests`, `blocked`: arrays of integer peer IDs.
- `chat`: array `{id, from, name, channel, text, time}`; no recipient lists.
- `party` / `guild`: `{id, leader, members: Array[int]}` plus guild `name`;
  empty dictionary if absent. Private pending invites are stripped.
- `invitations`: `{party: Array[{id, leader, name}], guild: Array[...]}`.
- `mail` and alias `inbox`: own letters `{id, from, from_name, to, subject,
  body, read, time}`.
- `trade`: empty or `{id, participants: Array[int], accepted: bool,
  offers: {integer_peer_id: {copper, items}}, confirmed: Array[int]}`.

## Trade safety

One pending or accepted trade per participant. The recipient must accept before
any offer can be confirmed. Changing either offer clears both confirmations.
Server profiles are checked again when the second participant confirms. Both
final bags, stack limits, capacity and copper balances validate before either
profile changes. Invalid trades transfer nothing and clear confirmations.
Successful trade IDs are removed, so repeated confirmation cannot award twice.
Disconnect or block cancels an unfinished trade without transferring anything.
The resulting profiles are committed together. Item locks, quest-reserved swords,
mounted items and time-limited leases cannot bypass protection via trade/auction.

## Shared world and bounties

Input packets contain normalized world-XZ direction and facing yaw, never an
accepted client position. Input expires after 350ms; bounds and swept geometry
checks constrain movement. Ten-Hz snapshots contain public actors/monsters and
only the recipient's private full profile/journal. Reliable events carry damage
feedback; dead targets cannot grant duplicate reward. One shared first zone has
sixteen keyed encounters. Pets use the same authoritative owner/death path.

Peaceful mode blocks outgoing PvP, party mode protects own party, guild mode
protects own guild, and free mode allows friendly fire. A mutually accepted duel
overrides peaceful mode and ends at one HP without death. Either player can
cancel it. These precise modes are modern tuning, not decoded original rules.

The bounty board reserves the issuer's entire reward. One assigned hunter must
meet its minimum level and defeat the target the specified number of times.
Only the WorldSimulation nonduel death callback can advance it; there is no
client-reported kill API. Accepted progress survives issuer disconnection and
host restart. Completion pays once; available cancellation refunds once.

## Verified checks

`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script
res://tests/social_state_test.gd` passes 46 pure-logic checks, covering privacy,
friendship, party/guild permissions, mail ownership, transactional trade,
capacity failure, offer change, replay and disconnect.

The same script supports `-- --transport-host` and `-- --transport-client`.
Run host first, then client concurrently within 8 seconds. It uses localhost UDP
port 17877. The client checks server admission rejects its fake uploaded money
and inventory, then exchanges actual RPC chat and friendship with the host.
Both report `TRANSPORT_HOST: PASS` / `TRANSPORT_CLIENT: PASS`.

`python tools/check_world_transport.py` runs two actual world clients, verifies
remote avatars, server movement, mutual duel consent and remote authoritative HP.
`python tools/run_checks.py` runs the current complete focused regression set.

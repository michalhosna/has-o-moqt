---
title: "Transporting HTTP Adaptive Streaming over Media over QUIC Transport"
abbrev: "HAS-o-MoQT"
category: std

docname: draft-hosna-moq-has-o-moqt-latest
submissiontype: IETF
number:
date:
consensus: true
v: 3
area: "Web and Internet Transport"
workgroup: "Media Over QUIC"
keyword:
 - HAS
 - DASH
 - HLS
 - CMAF
 - adaptive streaming
 - MoQ
venue:
  group: "Media Over QUIC"
  type: "Working Group"
  mail: "moq@ietf.org"
  arch: "https://mailarchive.ietf.org/arch/browse/moq/"
  github: "michalhosna/has-o-moqt"
  latest: "https://michalhosna.github.io/has-o-moqt/draft-hosna-moq-has-o-moqt.html"

author:
 - fullname: "Michal Hosna"
   organization: CDN77
   email: "mh@michalhosna.com"

normative:
  RFC20:   # USASCII
  RFC9110: # HTTP Semantics
  RFC3986: # URI
  RFC8259: # JSON
  RFC1952:  # GZIP file format
  MoQTransport: I-D.ietf-moq-transport
  MSF: I-D.ietf-moq-msf
  LOC: I-D.ietf-moq-loc
  I-D.pantos-hls-rfc8216bis:
  MPEG-DASH:
    target: https://www.iso.org/standard/83314.html
    title: "Information technology — Dynamic adaptive streaming over HTTP (DASH) — Part 1: Media presentation description and segment formats"
    seriesinfo:
      ISO/IEC: 23009-1:2022
    date: 2022
  CMAF:
    target: https://www.iso.org/standard/85623.html
    title: "Information technology — Multimedia application format (MPEG-A) — Part 19: Common media application format (CMAF) for segmented media"
    seriesinfo:
      ISO/IEC: 23000-19:2024
    date: 2024

informative:
  RFC8126:  # IANA registration policies
  RFC8216:  # HLS
  RFC9111:  # HTTP Caching
  RFC8246:  # HTTP Immutable Responses
  RFC3967:  # BCP 97 downrefs
  RFC8067:  # BCP 97 update


--- abstract

This document defines a format-agnostic mapping of HTTP Adaptive Streaming (HAS) presentations onto Media over QUIC Transport (MOQT). Media units are carried unchanged and can be reconstructed byte-identically; manifests are reconstructed as semantically equivalent documents. A publisher that understands the container can expose finer-grained Objects.


--- middle

# Introduction

HAS structures a media presentation as a manifest plus independently retrievable media segments, pulled over HTTP {{RFC9110}}. HTTP is request/response, supports per-hop caching, and requires clients to poll the manifest. MPEG-DASH {{MPEG-DASH}} and HLS {{RFC8216}} are the common formats.

Media over QUIC Transport (MOQT) {{MoQTransport}} delivers media as a publish/subscribe stream of addressable Objects through relays that fan out subscriptions and may cache. Ingress and Egress Gateways allow existing HTTP players to receive HAS presentations transported over a MOQT backbone.

This document specifies that mapping. Segments are carried unchanged and reconstructed byte-identically at the egress; Manifests are reconstructed as semantically equivalent documents. A Subscriber that understands the carried container can consume the media directly from MOQT.

This mapping provides a compatibility option for existing HAS deployments. This document does not recommend it over other media delivery approaches. A design goal is to provide an end-user experience no worse than that of delivering the same Presentation over HTTP.

This document describes version 1 of the mapping.

# Scope

This document:

- Maps a HAS Presentation onto MOQT such that a Consumer reconstructs the same Presentation.
- Lets a Subscriber consume the Presentation directly from MOQT.
- Keeps the HAS Manifest the authoritative source for structure, adaptation and timing.
- Covers low-latency live, conventional live and on-demand.
- Lets a Presentation and an MSF catalog {{MSF}} coexist in one Track Namespace, referencing the same Media Stream Tracks ({{msf-relationship}}).

The mapping is generic over streaming formats that deliver a manifest and segments over HTTP. A Format Definition ({{formats}}) specializes it for one format. This document contains the Format Definitions for DASH ({{dash}}) and HLS ({{hls}}); other Formats are extensions. Media Stream Tracks are Format-independent; Manifests of several Formats can reference one Track.

Out of scope:

- A new media packaging or adaptation-set/catalog model.
- Generating a Format the Presentation does not carry.

# Conventions and Definitions {#conventions}

{::boilerplate bcp14-tagged}

This document uses the terminology of {{MoQTransport}}.

Note (to be removed before publication): this document also applies to {{MoQTransport}} versions before -20; there a SUBSCRIBE carrying FILL_PARAMETERS is a Joining Fetch ([Section 10.12.2 of draft-ietf-moq-transport-18](https://www.ietf.org/archive/id/draft-ietf-moq-transport-18.html#section-10.12.2)).

The sub-namespace labels (`mapping`, `manifest`, `data`), reserved Track Names (`has-o-moqt-mapping`), and Track Namespace Field values this document defines are US-ASCII ({{RFC20}}) octets, compared byte-for-byte ({{Section 2.4.1 of MoQTransport}}). Track Names a Publisher binds through the Mapping Manifest ({{mapping-manifest}}) are JSON strings; the Track Name octets are the string's UTF-8 encoding ({{Section 8.1 of RFC8259}}).

TODO: Binary Track Names are not representable; follow [moq-wg/msf#209](https://github.com/moq-wg/msf/issues/209) and adopt whatever MSF settles on.

The outer Track Namespace Fields are a deployment choice ({{namespaces}}); their values are opaque octets.

"HAS-o-MoQT" names this mapping; the lowercase form `has-o-moqt` appears only in identifiers.

A *sub-namespace* of a Track Namespace is the Track Namespace formed by appending one Track Namespace Field to it; a PUBLISH_NAMESPACE for the shorter namespace covers it ({{Section 9.5 of MoQTransport}}).

The following terms are used with the first letter capitalized.

Presentation:
: One HAS live stream or on-demand asset, identified by a single top-level manifest.

Manifest:
: A document describing a Presentation.

Format:
: A HAS manifest format, identified by its `flavor` value and specified by a Format Definition ({{formats}}).

Snapshot Track:
: The Track carrying a Manifest as full documents, one per Group ({{snapshot-track}}).

Delta Track:
: The Track carrying each state of a Manifest in the Format's delta form ({{delta-extension}}).

Manifest Version:
: The Format-defined identity of one Manifest state ({{manifest-version}}).

Index Track:
: The Track binding a Media Stream Track's Groups to Request Paths ({{index-track}}).

Media Stream:
: One independently selectable encoding within a Presentation.

Segment:
: One independently addressable media unit of a Media Stream: a whole retrievable file, or a byte range of a larger resource.

Chunk:
: A self-delimiting sub-Segment unit the carried container defines.

Initialization Data:
: The bytes a decoder needs before consuming a Media Stream's Segments.

Ingress Gateway:
: An Original Publisher that converts existing HAS into MOQT.

Egress Gateway:
: The entity that subscribes to a Presentation and reconstructs its Manifests and Segment responses for HTTP players.

Consumer:
: A Subscriber to a Presentation's Tracks: an Egress Gateway, or a player consuming the Presentation directly from MOQT.

Mapping Manifest:
: The document binding a Presentation's HTTP resources to Tracks and Locations ({{mapping-manifest}}). Distinct from the carried original Manifests.

Request Path:
: The path component ({{Section 3.3 of RFC3986}}) of the target URI ({{Section 7.1 of RFC9110}}) of an HTTP request for a resource of the Presentation.

Root Path:
: The prefix every Request Path of a Presentation shares ({{addressing}}).

# Overview {#overview}

A Presentation becomes one Track Namespace with three sub-namespaces ({{namespaces}}); each Segment becomes one Group of its Media Stream's Track.

~~~
Track Namespace
  mapping/
    Mapping Manifest Track
    Index Tracks
  manifest/
    Snapshot Tracks
    Format extension Tracks
  data/
    Media Stream Tracks
~~~

# Mapping HAS to MOQT

## Presentation to Track Namespace {#namespaces}

A Presentation maps to exactly one Track Namespace. The Original Publisher MUST advertise it with one PUBLISH_NAMESPACE. The Track Namespace itself holds no Tracks; it contains the following sub-namespaces:

- `mapping`: the Mapping Manifest Track ({{mapping-manifest}}) and the Index Tracks ({{index-track}}).
- `manifest`: the Snapshot Tracks and Format extension Tracks ({{sec-manifest}}).
- `data`: the Media Stream Tracks ({{groups}}) and, where the Presentation also exposes an MSF catalog, the catalog track ({{msf-relationship}}).

## Relationship to MSF Catalogs {#msf-relationship}

A Publisher MAY expose the same media as both a HAS-o-MoQT Presentation and an MSF {{MSF}} catalog of any streaming format. Placing the catalog track (Track Name `catalog`, {{Section 5 of MSF}}) in the `data` sub-namespace lets catalog entries reference the Media Stream Tracks by name alone, through namespace inheritance ({{Section 5.2.2 of MSF}}). The `mapping` and `manifest` sub-namespaces play no part in the catalog. The Track Name `catalog` is reserved in the `data` sub-namespace.

## Media Stream to Track {#track}

Each Media Stream maps to one Track. The Mapping Manifest binds each Manifest's identifiers to Track Names ({{mapping-manifest}}). A change of Initialization Data or encoding along a Media Stream begins a new Track; a Format Definition MUST define the Manifest events that require a new Track.

## Segment to Group {#groups}

Each Segment maps to one Group. The Original Publisher MUST publish Group IDs that increase with the media timeline along a Media Stream, assigned by the Track's addressing scheme ({{addressing}}). The Original Publisher MUST NOT set the Prior Group ID Gap property ({{Section 12.8 of MoQTransport}}) over a Segment it may still publish.

## Segment Addressing {#addressing}

Every Request Path of a Presentation begins with its Root Path. Manifest references outside it (keys, license servers) are not resources of the Presentation; players fetch them directly. Every path this document carries in MOQT is relative to the Root Path. How an HTTP authority and the Root Path map to a Track Namespace is deployment configuration ({{egress-config}}).

A Request Path cannot in general be reversibly encoded as a Full Track Name and Location. Object 0 of each Group carries the Segment's Request Path and byte range in `HAS_ORIGINAL_REFERENCE` ({{original-reference}}). The Track's addressing entry in the Mapping Manifest ({{mapping-manifest}}) resolves a Request Path to a Group ID by its `scheme` field:

- `template`: the entry contains a String `template` and Numbers `startNumber` and `startGroup`.
- `time`: the entry contains a String `template` and Numbers `startTime`, `duration` and `startGroup`.
- `index`: the entry contains `indexTrack`, a String giving the Track Name of the Media Stream Track's Index Track in the `mapping` sub-namespace ({{index-track}}).

The numeric fields are non-negative integers, except `duration`, which MUST be a positive integer. `startGroup` and every calculated Group ID MUST be in the Group ID range defined by {{MoQTransport}}. A Consumer MUST perform the calculations below without loss of integer precision.

A Segment has exactly one Request Path; Manifests of every Format reference it by that Request Path. A Request Path MUST NOT match more than one addressing entry of a Presentation.

### Template Syntax

A template is a path relative to the Root Path. A `template` entry MUST contain exactly one `$Number$` or `$Number%0<width>d$` capture. A `time` entry MUST contain exactly one `$Time$` or `$Time%0<width>d$` capture. The width is a positive decimal integer.

An unformatted capture matches a non-negative decimal integer with no leading zeros, except for the value zero. A formatted capture matches that integer zero-padded to at least the specified width. In either template, `$$` matches a literal `$`; every other octet matches itself.

### Group ID Calculation

For a `template` entry, let V be the captured integer. The Group ID is:

~~~
V - startNumber + startGroup
~~~

A value below `startNumber` matches no Segment. A restart of the Segment numbering begins a new Track.

For a `time` entry, let V be the captured integer. The Group ID is:

~~~
(V - startTime) / duration + startGroup
~~~

A value matches no Segment unless it is `startTime` plus a whole non-negative multiple of `duration`. A Track with varying Segment durations uses `index` addressing.

A captured value that would produce a Group ID outside the valid range matches no Segment.

## Object Structure within a Group {#packaging}

Every Track this document defines carries its Objects in Subgroup 0.

A Segment's bytes are carried verbatim as the Objects of its Group:

- Object 0 MUST begin at a random-access point.
- The Objects of a Group MUST carry Object IDs 0 to N with no gap, where N is the last Object.
- The Publisher MUST signal the end of the Group ({{Section 11.2.1.1 of MoQTransport}}, {{Section 11.4.2 of MoQTransport}}).

A Publisher MAY carry a Segment as a single Object or split it across several. Object boundaries carry no media semantics. A Publisher SHOULD align Object boundaries to the container's Chunk boundaries. The Publisher MUST set the `HAS_OBJECT_OFFSET` property ({{codepoints}}) on every Object of the Group: the Object's byte offset within the Segment, as a varint. Object offsets within a Segment MUST describe a contiguous byte sequence beginning at offset zero.

A Format Definition MUST define the containers the Format carries: the Chunk, the random-access point, and whether the container is self-initializing.

Encrypted samples and in-band DRM metadata pass through unchanged; the mapping does not decrypt, re-encrypt, or parse media.

TODO: Consider non-byte-exact carriage (locmaf, transmuxing between containers) and how to communicate the Egress Gateway requirements for reconstruction.

## Original Reference {#original-reference}

`HAS_ORIGINAL_REFERENCE` ({{codepoints}}) is an Object Property. A Publisher MUST set it on Object 0 of every Group of a Media Stream Track. The value is a JSON object:

- `path`: String. The Segment's Request Path relative to the Root Path.
- `range`: String. Present where the Segment is a byte range of a larger resource; the range in HTTP `first-last` form ({{Section 14.1.2 of RFC9110}}).

## Part Reference {#part-reference}

A Format MAY address parts: sub-Segment units with their own Request Paths or byte ranges, advertised by its Manifests. On a Track carrying parts, the Publisher MUST align Object boundaries to part boundaries and MUST set `HAS_PART_REFERENCE` ({{codepoints}}) on the first Object of each part: a JSON object as in {{original-reference}}, holding the part's Request Path and byte range.

A Consumer resolves a part from the `HAS_PART_REFERENCE` values it has received. A part no Manifest still advertises may be unresolvable.

## Initialization Data {#init}

A Media Stream's Initialization Data is carried either as the `VIDEO_CONFIG` ({{Section 2.3.2.1 of LOC}}) or `AUDIO_CONFIG` ({{Section 2.3.3.1 of LOC}}) Track Property on that Media Stream's Track, or inline in the Mapping Manifest ({{mapping-manifest}}). A self-initializing container has no Initialization Data.

## Response Header Fields {#response-headers}

The original response header fields of each HTTP resource are carried in the `HAS_RESPONSE_HEADERS` property ({{codepoints}}), at two levels:

- As a Track Property: the header fields common to every response reconstructed from the Track. A Publisher MUST set it on every Track that reconstructs an HTTP response (every Media Stream Track and Snapshot Track, and extension Tracks as their extension defines), and MUST include `Content-Type` set to the reconstructed resource's registered media type.
- As an Object Property on Object 0 of a Group: the header fields in which that Segment's response differs from the Track level. A Publisher MAY set it.

The value is a JSON object keyed by lower-cased field name ({{Section 5.1 of RFC9110}}). A member value is a String (one field line), an Array of Strings (one field line per element), or `null`.

The header fields of a response are the members of the Track-level property, each replaced by the Object-level member of the same field name where one exists, plus the remaining Object-level members; members with value `null` are omitted. An Ingress Gateway MUST keep the source's order of the field lines of one field name within the Array, and an Egress Gateway MUST emit them in that order. The order of fields with different field names is not significant ({{Section 5.3 of RFC9110}}).

TODO: Consider a more concise encoding and/or compression, especially for per-Object headers.

A Publisher MUST NOT carry the following header fields in these properties, and a Consumer MUST ignore them if present:

- `Content-Range`
- `Vary`
- connection-specific header fields ({{Section 7.6.1 of RFC9110}})

TODO: Give either a more exhaustive list or a general rule; the behavior is intended to match an HTTP proxy's.

TODO: Specify `Vary` handling at the Ingress Gateway; it should not accept resources with a `Vary` header.

## Manifest Carriage {#sec-manifest}

A Format Definition MUST define which documents of a Presentation are its Manifests. Each Manifest is carried on a Snapshot Track in the `manifest` sub-namespace, named by the Mapping Manifest ({{mapping-manifest}}). A Format extension ({{formats}}) MAY add Tracks per Manifest to the `manifest` sub-namespace, named in the Mapping Manifest. A Consumer that does not implement the extension ignores them.

### Snapshot Track {#snapshot-track}

The Original Publisher MUST publish a Snapshot Track for every carried Manifest:

- Each Group holds exactly one Object (Object ID 0): the full Manifest in the Format's snapshot form.
- Each Group's ID MUST be one greater than that of the previous Group.
- Each Object MUST carry the `HAS_MANIFEST_VERSION` Object Property where the Format defines a version for the Manifest ({{manifest-version}}).
- The Publisher MUST start a new Group at every reset point the Format defines ({{formats}}) and at the end of the Presentation.
- For a live Presentation, the Publisher MUST publish a new Group on every Manifest change.

A Format Definition MUST define the snapshot form: the full Manifest with every feature removed that a Consumer of the Snapshot Track alone could not honor.

An Egress Gateway serves the latest Snapshot Object verbatim, unless it implements a Format extension that defines otherwise.

### Manifest Version Property {#manifest-version}

`HAS_MANIFEST_VERSION` ({{codepoints}}) is an Object Property identifying one Manifest state. Its value is US-ASCII octets whose grammar and ordering the Format defines ({{formats}}). A Format MAY leave a Manifest without a version; its Objects carry no `HAS_MANIFEST_VERSION`.

## Mapping Manifest {#mapping-manifest}

The Mapping Manifest is a JSON document carried on its own Track in the `mapping` sub-namespace ({{namespaces}}), under the reserved Track Name `has-o-moqt-mapping`. The Original Publisher MUST publish it. Track Names in the Mapping Manifest are UTF-8 ({{conventions}}).

Object 0 of each Group is a full document; later Objects are update documents ({{mapping-updates}}). The Publisher MUST start a new Group before any Object of the current Group expires under the Track's `MAX_CACHE_DURATION` ({{Section 12.3 of MoQTransport}}), and SHOULD start one often enough to bound the updates a joining Consumer processes.

Tracks, Initialization Data and addressing can change during playback. A Consumer MUST process each new Mapping Manifest version as it arrives.

Two version numbers are carried as Track Properties on the Mapping Manifest Track; the two advance independently:

- `HAS_O_MOQT_VERSION` ({{codepoints}}): the HAS-o-MoQT revision, 1 for this document.
- `HAS_MAPPING_SCHEMA_VERSION` ({{codepoints}}): the Mapping Manifest schema, 1 for this document.

A Consumer MUST NOT consume a Presentation whose `HAS_O_MOQT_VERSION` or `HAS_MAPPING_SCHEMA_VERSION` it does not implement, and MUST ignore Mapping Manifest fields it does not recognize.

The following rules apply to the Mapping Manifest:

- Unless specified otherwise, fields listed in this section are REQUIRED.
- Track Names and references to entry identifiers are JSON Strings.
- Each `manifests` entry has a unique `path` within the Mapping Manifest.
- Each `tracks` entry has a unique `name` within the Mapping Manifest.
- Each `initDataList` entry has a unique `id` within the Mapping Manifest.
- Every `track` and `initRef` reference MUST identify a declared entry.

A Consumer MUST reject a Mapping Manifest document that omits a required field, uses an invalid type or value for a recognized field, contains duplicate entry identifiers, or leaves an unresolved entry reference. A Consumer MUST validate an update document's resulting state before replacing its previous state. Unrecognized fields are ignored as specified above.

Rejecting a document has the following consequences:

- The Consumer MUST NOT use the rejected document to establish or replace its Mapping Manifest state. Any previous valid state remains unchanged; no operation of a rejected update is applied.
- The Consumer MUST NOT apply subsequent update Objects in the rejected document's Group, because they depend on the state that document would have produced.
- To resume applying Mapping Manifest documents, the Consumer MUST obtain a valid full document from Object 0 of a later Group ({{mapping-updates}}).

Rejection of a Mapping Manifest document does not by itself require terminating the MOQT connection.

Root fields:

- `generatedAt`: Number, a non-negative integer giving milliseconds since the Unix epoch. Optional.
- `fallbackOrigin`: String, an absolute URL prefix: the egress fallback for unbound Request Paths ({{egress}}). Optional.
- `isLive`: Boolean. True for a live Presentation, false for on-demand; changes only to false, when a live Presentation ends.
- `manifests`: Array of entries for the carried original Manifests (below).
- `initDataList`: Array of Initialization Data entries (below).
- `tracks`: Array of Track entries (below).

Each `manifests` entry binds one original Manifest to its Tracks ({{sec-manifest}}):

- `flavor`: String identifying the Format ({{formats}}). This document defines `dash` ({{dash}}) and `hls` ({{hls}}).
- `path`: String. The Manifest's Request Path relative to the Root Path.
- `snapshotTrack`: Track Name of the Snapshot Track, in the `manifest` sub-namespace.
- `extension`: Object. Fields of the Format extensions in use for this Manifest ({{formats}}). Optional.
- `media`: Array of bindings from the Manifest's own identifiers to Media Stream Tracks. Each binding contains `track`, the Track Name in the `data` sub-namespace, and the Format-defined identifier fields ({{formats}}). Optional for a Manifest that does not directly identify any Media Streams.

Each `initDataList` entry follows {{Section 5.1.7 of MSF}}:

- `id`: String, unique within the Mapping Manifest; Tracks reference it via `initRef`.
- `type`: String, either `"inline"` as in {{MSF}}, or `"track-property"` ({{init}}), which this document defines.
- `data`: String, by `type`:
  - `"inline"`: the Initialization Data in base64 ({{Section 5.1.7 of MSF}}).
  - `"track-property"`: the Property Type of the Track Property carrying it ({{init}}), as a hex string: `0x0D` for `VIDEO_CONFIG`, `0x0F` for `AUDIO_CONFIG`.
- `path`: String. The Request Path of the Initialization Data resource, relative to the Root Path.
- `range`: String. Present where the Initialization Data is a byte range of a larger resource; as in {{original-reference}}.
- `headers`: Object. The response header fields of the Initialization Data resource, in the value form of {{response-headers}}; MUST include `Content-Type`.

Each `tracks` entry describes one Media Stream Track:

- `name`: String. The Track Name in the `data` sub-namespace.
- `initRef`: String. The `initDataList` `id` of this Media Stream's Initialization Data. REQUIRED when the container is not self-initializing; omitted otherwise ({{init}}).
- `addressing`: Object. The addressing entry ({{addressing}}), containing `scheme` and the scheme's fields.

### Updates {#mapping-updates}

An update document holds one root field, `deltaUpdate`: an Array of operation objects applied in order to the document produced by the previous Object of the Group. Each operation carries `op` and one of `tracks`, `manifests` or `initDataList`, an Array of entries of that kind:

- `add`: entries not previously declared.
- `remove`: entries to remove, each holding only its `name`, `path` or `id`.
- `clone`: `tracks` only, as in {{Section 5.1.6 of MSF}}.

An entry's fields do not change after it is declared; a change is a `remove` of the entry and an `add` of a new one, in that order within one update document. A Track entry references its `initDataList` entry by `initRef`; an update document that adds both lists the `initDataList` operation first.

Update documents change only the `tracks`, `manifests` and `initDataList` arrays. To change any other root field, including setting `isLive` to false when a live Presentation ends, the Publisher MUST begin a new Group whose Object 0 contains the complete updated Mapping Manifest.

## Index Track {#index-track}

An `index`-addressed Media Stream Track ({{addressing}}) has one Index Track. It uses the Object structure of the Mapping Manifest Track: Object 0 of each Group is a full Index Document, later Objects are update documents ({{index-updates}}).

### Index Document {#index-document}

A JSON object with one root field, `bindings`: an Array of Segment bindings ordered by `group` ascending, one per published Group of the Media Stream Track:

- `group`: Number. The Group ID.
- `path`: String. The Segment's Request Path relative to the Root Path.
- `range`: String. Present where the Segment is a byte range; as in {{original-reference}}.

`path` and `range` equal the Group's `HAS_ORIGINAL_REFERENCE` value ({{original-reference}}). The bindings sharing one `path` MUST tile the resource contiguously, ordered by `group`. The Original Publisher MUST publish a Segment's binding no later than any Manifest Object referencing the Segment. A full document holds the bindings of every Group the Original Publisher retains.

### Updates {#index-updates}

An update document holds the same root field; its entries append to the held Array. An expired Group's bindings disappear at the next full document.

## Payload Compression {#compression}

A Publisher MAY compress non-media Track payloads (the Mapping Manifest, the Index Tracks, and the Tracks of the `manifest` sub-namespace) with the `MSF_COMPRESSION` Track Property or Object Property, under the rules of {{Section 12.1 of MSF}}. A Consumer MUST support the algorithms {{MSF}} mandates (GZIP, {{RFC1952}}).

TODO (downref): {{RFC1952}}, {{MSF}} and {{I-D.pantos-hls-rfc8216bis}} are Informational; the normative references to them are downrefs under BCP 97 ({{Section 1 of RFC3967}}, {{Section 2 of RFC8067}}). Call out in the IETF Last Call and record in the [downref registry](https://datatracker.ietf.org/doc/downref/). If [moq-wg/moq-transport#1850](https://github.com/moq-wg/moq-transport/issues/1850) is adopted, switch to the transport's compression properties and drop both references.

## Format Definitions {#formats}

A Format Definition binds one `flavor` value ({{mapping-manifest}}) to the Format-defined parts of the mapping; the rest of this document treats a Format as opaque. It declares the Format extensions the Format adopts. This document defines the DASH and HLS mappings; additional Format Definitions are specified in separate documents.

A Format Definition MUST specify:

- The documents that are Manifests ({{sec-manifest}}).
- The snapshot form of each Manifest ({{snapshot-track}}).
- Whether each Manifest has a version and, if so, its grammar and ordering ({{manifest-version}}).
- The reset points that start new Snapshot Groups ({{snapshot-track}}).
- The Manifest identifiers used in `media` bindings ({{mapping-manifest}}).
- The Manifest events that require a new Media Stream Track ({{track}}).
- The supported containers, their Chunk and random-access boundaries, and whether they are self-initializing ({{packaging}}).
- The adopted Format extensions and any Format-specific definitions those extensions require.

A Format extension defines Tracks, Properties or `extension` fields beyond the generic mapping, for use by any Format that adopts it. A Consumer implements an extension per Format.

## Property Codepoints {#codepoints}

Property Types are taken from the application-specific range 0x3800 to 0x3FFF of {{Section 2.5 of MoQTransport}}. An even Type carries a varint value, an odd Type length-prefixed octets ({{Section 1.4.3 of MoQTransport}}). This document and its revisions allocate 0x3800 to 0x38FF; a Format or extension document allocates from 0x3900 to 0x3FFF and lists its codepoints. A Consumer interprets a property only per the Formats and extensions declared for the Presentation ({{mapping-manifest}}).

| Type   | Name                          | Scope  | Value      | Defined in |
|-------:|-------------------------------|--------|------------|------------|
| 0x3800 | `HAS_O_MOQT_VERSION`          | Track  | varint     | {{mapping-manifest}} |
| 0x3801 | `HAS_RESPONSE_HEADERS`        | Track, Object | JSON text  | {{response-headers}} |
| 0x3802 | `HAS_MAPPING_SCHEMA_VERSION`  | Track  | varint     | {{mapping-manifest}} |
| 0x3803 | `HAS_ORIGINAL_REFERENCE`      | Object | JSON text  | {{original-reference}} |
| 0x3806 | `HAS_OBJECT_OFFSET`           | Object | varint     | {{packaging}} |
| 0x3807 | `HAS_PART_REFERENCE`          | Object | JSON text  | {{part-reference}} |
| 0x3809 | `HAS_MANIFEST_VERSION`        | Object | US-ASCII   | {{manifest-version}} |

A Consumer MUST interpret these types only on Tracks of a HAS-o-MoQT Presentation ({{namespaces}}).

## Live Edge, Seeking and DVR {#live-edge}

A Consumer locates a Segment through the Mapping Manifest alone ({{addressing}}). The Track's Largest Object places the located Group relative to the live edge, which decides the retrieval and, at an Egress Gateway, the response state ({{status-mapping}}):

- Live edge: the newest Segment is the Group of the Largest Object; new Segments arrive as new Groups. To follow the edge the Consumer subscribes to the Track.
- Joining at a past Group: a SUBSCRIBE carrying FILL_PARAMETERS ({{Section 10.2.15 of MoQTransport}}) delivers the subscription filter's past range on a fill fetch stream.
- DVR and on-demand seeking: a FETCH over an explicit Group range ({{Section 5.1.2 of MoQTransport}}).
- Seeking by media time: for a `time`-addressed Track, from its addressing entry ({{addressing}}); else from the Manifest.

# Reconstructing HAS at the Egress Gateway {#egress}

An Egress Gateway receives an HTTP request, classifies its Request Path through the Mapping Manifest ({{mapping-manifest}}), and builds the response from MOQT:

- A Manifest request: as {{snapshot-track}} defines.
- An Initialization Data request: as {{init}} defines, at the `initDataList` `path`, served with the entry's `headers`.
- A Segment request: the Request Path resolves via {{addressing}} to a (Track, Group) or, for a resource carried as byte-range Segments, to the Groups covering the requested range ({{index-document}}). The response body is the concatenation of the resolved Groups' Objects, cut to the requested range by `HAS_OBJECT_OFFSET` ({{packaging}}).
- Any other Request Path: where `fallbackOrigin` is set ({{mapping-manifest}}), the gateway MAY proxy the request to `fallbackOrigin` plus the Request Path; else the response is `404`.

For a Segment carried as a byte range whose first resource byte is B, an Object with `HAS_OBJECT_OFFSET` O begins at resource byte B+O. For a whole-resource Segment, B is zero. The Egress Gateway selects the Objects intersecting the requested resource range, orders them by their resource offsets, and trims the first and last Objects to that range. It MUST NOT include bytes outside the requested range.

The Egress Gateway emits the header set of {{response-headers}} on every response. For a byte-range response it MUST add `Content-Range` and use status `206`; these are derived per request and are not among the carried fields.

{{egress-operation}} gives an informative example of gateway configuration, retrieval and subscription management.

## HTTP Status Codes {#status-mapping}

The HTTP status is determined by the existence state of the requested Objects ({{Section 2.1 of MoQTransport}}) together with the Segment's position relative to the live edge and the DVR window ({{groups}}). The following table gives the recommended status mapping. An Egress Gateway SHOULD use these statuses for the listed conditions.

| Condition | Status | Response behavior |
|-----------|-------:|-------------------|
| Group present and complete (end of Group signaled), whole-Segment request | `200` | Full body; `Content-Length` known |
| As above, satisfiable byte-range request | `206` | `Content-Range` for the requested range |
| Byte-range request that cannot be satisfied | `416` | `Content-Range: bytes */<len>`; for a shared resource, `<len>` is the last binding's range end |
| Group beyond the live edge (Group ID greater than the Group of the Largest Object), live Track | `200` | Hold the response until the Object arrives; `404` past the deadline |
| Group still open (end of Group not yet signaled), low-latency live | `200` | Stream Objects in the response body as they arrive; complete the response when the end of the Group is signaled |
| An Object of the Group known to not exist (a Non-Existent range in a FETCH response, {{Section 11.4.4.2 of MoQTransport}}, or Prior Object ID Gap, {{Section 12.9 of MoQTransport}}) | `404` | Segment is missing at the source |
| Group before the oldest Group the source retains | `404` (`410` if known permanently gone) | Outside the DVR window |
| Request beyond End of Track (finalized on-demand asset, or a live Presentation that has ended) | `404` | No such Segment |
| Request Path referenced by the served Manifest but not yet bound by an Index Track entry | `200` | Hold until the binding arrives ({{index-document}}); `404` past the deadline |
| Part request not yet resolvable ({{part-reference}}) | `200` | Hold until the part's first Object arrives; `404` past the deadline |
| Request Path not bound by the Mapping Manifest | `404`, or proxied | Proxied to `fallbackOrigin` where set ({{mapping-manifest}}); else not found |
| Upstream SUBSCRIBE / FETCH rejected by relay or origin | `502` | Upstream error, not a gateway fault |
| Upstream unreachable or no response within the gateway's deadline | `504` | Upstream timeout |
| Gateway's own failure | `500` | Internal error |

For a held response, the Egress Gateway MUST defer sending response headers until the condition for serving the response is met or its deadline expires. The `200` status in a hold row applies when that condition is met; the timeout status applies if the deadline expires first. Once response headers have been sent, the gateway cannot change the status; if retrieval subsequently fails, it MUST terminate the incomplete response using the applicable HTTP version's error handling.

When streaming an open Group, the Egress Gateway MUST use response framing appropriate to the HTTP version. It MUST NOT send a `Content-Length` unless the complete response length is known.

Manifest and Initialization Data requests use the same table: `200` when the resource is present on its Track, `404` when the Mapping Manifest has no such resource, and the `500`, `502` and `504` rows for upstream and internal failures. Delta and blocking requests ({{delta-extension}}) add:

| Condition | Status | Response behavior |
|-----------|-------:|-------------------|
| Delta request on a non-delta gateway | `200` or `404` | Full Manifest for a directive on the Manifest path; `404` for an unadvertised path ({{delta-track}}) |
| Delta request on a delta-capable gateway whose held state has no Delta Object ({{delta-track}}) | `200` or `404` | As a non-delta gateway |
| Blocking Manifest request on a non-delta gateway | `200` | Current Manifest, directive ignored |
| Blocking Manifest request on a delta-capable gateway, version not yet reached | `200` | Hold until the held version reaches the requested one ({{manifest-reconstruction}}); `404` past the deadline |

## HTTP Response Caching {#egress-caching}

An Egress Gateway SHOULD apply the following caching policy ({{RFC9111}}) to reconstructed responses, subject to operator configuration:

- `Cache-Control`: `max-age` derived from the resource's `MAX_CACHE_DURATION` ({{Section 12.3 of MoQTransport}}), plus `immutable` ({{RFC8246}}) for Segments and Initialization Data ({{Section 2.1 of MoQTransport}}). Further caching policy is left to the operator.
- `Vary`: omitted; the MOQT cache key (Full Track Name, Group ID, Object ID) takes no request-header input. The gateway emits `Vary: Accept-Encoding` only when it negotiates a content coding of its own.

# Built-in Extensions {#built-in-extensions}

This section defines the extensions and Format Definitions included in this document. Additional extensions and Format Definitions are specified in separate documents ({{formats}}).

## CMAF Containers {#cmaf-containers}

For a Format carrying CMAF {{CMAF}}: a Chunk is a CMAF Chunk (`moof`+`mdat`), Initialization Data is the CMAF Header (`ftyp`+`moov`), and the container is not self-initializing.

## Delta Track Extension {#delta-extension}

A Format MAY adopt this extension, which carries each state of a Manifest on a Delta Track in the Format's delta form. A Consumer opts in by subscribing to the Delta Track; nothing is negotiated with the Original Publisher.

A Format Definition adopting it MUST define:

- which of its Manifests may have a Delta Track; a Manifest without a version ({{manifest-version}}) cannot have one.
- the delta form: the document a Delta Object carries.
- how a Delta Object is applied to the held Manifest ({{manifest-reconstruction}}).
- the delta and blocking requests ({{egress-profiles}}).

The extension adds to the `manifests` entry's `extension` object ({{mapping-manifest}}):

- `deltaTrack`: Track Name of the Delta Track, in the `manifest` sub-namespace.
- `lowLatency`: Object. What a delta-capable gateway adds to the Manifest it serves; schema per Format. Optional.

### Delta Track {#delta-track}

The Original Publisher MAY publish a Delta Track for a carried Manifest:

- Delta Group G holds exactly one Object (Object ID 0) in the Format's delta form; applied to the Manifest of Snapshot Group G-1 it MUST produce that of Snapshot Group G, up to the features the snapshot form removes ({{snapshot-track}}).
- The Object MUST carry `HAS_MANIFEST_VERSION`, equal to Snapshot Group G's.
- The Publisher omits the Delta Group of a state it cannot express in the delta form and MUST set the Prior Group ID Gap property ({{Section 12.8 of MoQTransport}}) on the next one; a Consumer MUST recover its held state from the Snapshot Track as specified in {{manifest-reconstruction}}.

A Delta Track has no Request Path.

### Egress Gateway Profiles {#egress-profiles}

For each Format, an Egress Gateway operates as either a non-delta or a delta-capable gateway. Delta requests are HTTP requests that a delta-capable gateway answers using Delta Objects. Blocking requests are HTTP requests whose responses are deferred until a specified Manifest Version is available ({{status-mapping}}).

A non-delta gateway serves Manifests per {{snapshot-track}}.

A delta-capable gateway:

- Takes the latest Snapshot Object (Group G) as its held state, subscribes to the Delta Track with FILL_PARAMETERS whose Location Filter starts at Group G+1 ({{Section 5.1.2 of MoQTransport}}), and applies the Delta Objects in order ({{manifest-reconstruction}}).
- Serves the full Manifest from its held state, with the Format's low-latency additions ({{formats}}), and deltas from the Delta Objects.
- Serves a Manifest without a Delta Track as a non-delta gateway does.

Serving a Snapshot Object verbatim preserves the bytes of the published snapshot form ({{snapshot-track}}), which may differ from the source Manifest. A Manifest reconstructed from Delta Objects is semantically equivalent to the corresponding snapshot form, with any low-latency additions specified by the Format.

### Manifest Reconstruction {#manifest-reconstruction}

A Consumer of a Delta Track MUST maintain one held state per Manifest, consisting of a reconstructed Manifest and its corresponding Group ID.

- A Consumer MUST apply Delta Object G only to held state G-1. Applying it produces held state G, whose version is the Object's `HAS_MANIFEST_VERSION`.
- If a Consumer receives Delta Object G while its held state precedes G-1, it MUST wait for the intervening Delta Objects. If a Prior Group ID Gap indicates that a required Delta Group is absent, or the Consumer's deadline expires, the Consumer MUST obtain a Snapshot Object for Group G or a later Group and replace its held state.
- A Consumer MUST NOT apply a Delta Object whose Group ID is at or before its held state's Group ID.
- A Consumer MAY replace its held state with a Snapshot Object for the same or a later Group at any time.
- An Egress Gateway answering a blocking request MUST defer the response until its held Manifest Version reaches the requested version, subject to its response deadline.

## Format Definition: MPEG-DASH {#dash}

This section defines the Format Definition ({{formats}}) for MPEG-DASH {{MPEG-DASH}}, with `flavor` set to `dash`.

### Manifests

The MPD is the one Manifest.

### Extensions

DASH adopts the Delta Track extension ({{delta-extension}}); the MPD MAY have a Delta Track.

### Snapshot Form {#dash-snapshot}

A Snapshot Object ({{snapshot-track}}) is the MPD with the `PatchLocation` element removed.

### Delta Form {#dash-delta}

A Delta Object ({{delta-track}}) is one MPD Patch document; its `@originalPublishTime` is the `@publishTime` of the preceding Snapshot Object. The Publisher MUST remove operations addressing `PatchLocation` from it ({{dash-snapshot}}). The Delta Track's `Content-Type` ({{response-headers}}) is `application/dash-patch+xml`.

### Manifest Version {#dash-version}

`HAS_MANIFEST_VERSION` ({{manifest-version}}) is `MPD@publishTime` as an `xs:dateTime` string, ordered by time. A static MPD has no version.

### Reset Points

A change of `MPD@id` starts a new Snapshot Group ({{snapshot-track}}).

### Low-Latency Advertisement

The `lowLatency` field ({{delta-extension}}) is `{ "patchLocation": { "path", "ttl" } }`: the `PatchLocation` element's path relative to the Root Path and `@ttl`. A delta-capable gateway inserts the element into the served MPD.

### Delta Requests

- A request for `patchLocation.path`: a delta-capable gateway serves the Delta Object of its held state; it answers `404` where the held state has no Delta Object ({{delta-track}}), as does a non-delta gateway ({{status-mapping}}).
- DASH has no blocking Manifest request.

### Reconstruction {#dash-reconstruction}

A Delta Object is applied as an MPD Patch to the held MPD ({{manifest-reconstruction}}).

### Media Identifiers {#dash-media}

A `media` binding ({{mapping-manifest}}) carries `representationId`, `adaptationSetId` and `periodId`.

### Addressing {#dash-addressing}

The addressing scheme ({{addressing}}) is derived from the MPD; this list is informative:

- `SegmentTemplate` with `$Number$`: a `template` entry. The Publisher substitutes `$RepresentationID$` and `$Bandwidth$` before recording the template; `startNumber` is the `SegmentTemplate` `startNumber`.
- `SegmentTemplate` with `$Time$` and `@duration`: a `time` entry; `startTime` is `@presentationTimeOffset` and `duration` is `@duration`, both in `@timescale` units.
- `SegmentTemplate` with `$Time$` and `SegmentTimeline`, `SegmentList`, `SegmentBase`: an `index` entry. The range of a `SegmentBase` Segment is its `mediaRange`; the Publisher parses the segment index (`sidx`) and binds one Group per subsegment.
- An Initialization Data Request Path is an Initialization Segment URL.

### Track Continuity {#multiperiod}

A Representation that remains the same Media Stream across a Period boundary keeps its Track, unless its Initialization Data changes or `$Number$` restarts ({{track}}, {{groups}}).

### Containers {#dash-containers}

The container is CMAF, as defined in {{cmaf-containers}}.

## Format Definition: HLS {#hls}

This section defines the Format Definition ({{formats}}) for HLS {{I-D.pantos-hls-rfc8216bis}}, with `flavor` set to `hls`.

### Manifests

The multivariant playlist and each media playlist are Manifests.

### Extensions

HLS adopts the Delta Track extension ({{delta-extension}}); a media playlist MAY have a Delta Track, the multivariant playlist MUST NOT.

### Snapshot Form {#hls-snapshot}

A Snapshot Object ({{snapshot-track}}) of a media playlist is the playlist served without delivery directives, with:

- `EXT-X-SERVER-CONTROL` without `CAN-BLOCK-RELOAD`, `CAN-SKIP-UNTIL` and `CAN-SKIP-DATERANGES`.
- `EXT-X-PRELOAD-HINT` and `EXT-X-RENDITION-REPORT` omitted.

`EXT-X-PART` tags are retained. A Snapshot Object of a multivariant playlist is the playlist unchanged.

### Delta Form {#hls-delta}

A Delta Object ({{delta-track}}) is one Playlist Delta Update: the response to `_HLS_skip=YES` at that state. The Delta Track's `Content-Type` ({{response-headers}}) is the playlist's.

### Manifest Version {#hls-version}

For a media playlist, `HAS_MANIFEST_VERSION` ({{manifest-version}}) is `<msn>` or `<msn>/<part>` in decimal: the Media Sequence Number of the last listed segment and, while that segment is incomplete, the index of its last Partial Segment. Versions order by Media Sequence Number, then Part Index; a version without a part is later than any part of that segment. The multivariant playlist has no version.

### Reset Points

`EXT-X-ENDLIST` starts the final Snapshot Group ({{snapshot-track}}).

### Low-Latency Advertisement {#hls-lowlatency}

The `lowLatency` field ({{delta-extension}}) is `{ "serverControl": "<attribute-list>" }`: the source's `EXT-X-SERVER-CONTROL` attribute list; `CAN-SKIP-DATERANGES` MUST NOT appear in it. A delta-capable gateway serves the playlist with:

- `EXT-X-SERVER-CONTROL` from `serverControl`, in place of the snapshot's.
- `EXT-X-PRELOAD-HINT` and `EXT-X-RENDITION-REPORT` from the last Delta Object applied ({{manifest-reconstruction}}).

### Delta and Blocking Requests

Delivery directives ({{Section 6.2.5.1 of I-D.pantos-hls-rfc8216bis}}):

- `_HLS_skip=YES`: a delta-capable gateway serves the Delta Object of its held state, else the full playlist; a non-delta gateway serves the full playlist ({{status-mapping}}).
- `_HLS_skip=v2`: every gateway serves the full playlist ({{status-mapping}}).
- `_HLS_msn`/`_HLS_part`: a delta-capable gateway holds the request until the held version ({{manifest-reconstruction}}) reaches the requested one ({{hls-version}}); a non-delta gateway ignores the directive.

### Reconstruction {#hls-reconstruction}

A Consumer merges a Delta Object with its held playlist using the Playlist Delta Update rules of {{Section 6.3.7 of I-D.pantos-hls-rfc8216bis}}. Let M be the Delta Object's `EXT-X-MEDIA-SEQUENCE` value and K its `EXT-X-SKIP` `SKIPPED-SEGMENTS` value, or zero if `EXT-X-SKIP` is absent. The reconstructed playlist contains:

1. The held segments with Media Sequence Numbers from M through M+K-1, inclusive, when K is greater than zero.
2. The segments listed in the Delta Object, beginning at M+K.

Segments preceding M are discarded. The Consumer MUST preserve the skipped segments' associated tags and the `EXT-X-KEY` and `EXT-X-MAP` values that apply to them. It uses the Delta Object's playlist-level tags and metadata and removes `EXT-X-SKIP` from the reconstructed full playlist.

If the held playlist lacks any information needed to restore the skipped portion, the Consumer MUST obtain a Snapshot Object for the Delta Object's Group or a later Group and replace its held state ({{manifest-reconstruction}}).

### Media Identifiers {#hls-media}

A `media` binding ({{mapping-manifest}}) carries `mediaPlaylistPath`, the Media Playlist's Request Path relative to the Root Path.

### Addressing {#hls-addressing}

The addressing scheme ({{addressing}}) is derived from the Media Playlist; this list is informative:

- Segment URIs that differ only in one decimal: a `template` entry. The Media Sequence Number plays no part in addressing.
- Any other URIs: an `index` entry. The range of an `EXT-X-BYTERANGE` Segment is its byte range.
- An Initialization Data Request Path is an `EXT-X-MAP` URI.

### Partial Segments {#hls-parts}

An `EXT-X-PART` or `EXT-X-PRELOAD-HINT` URI is a part ({{part-reference}}); its byte range, where present, is the `BYTERANGE` attribute.

### Track Continuity

An `EXT-X-DISCONTINUITY` that changes `EXT-X-MAP` begins a new Track ({{track}}). Otherwise, the Media Stream continues on the existing Track.

### Containers {#hls-containers}

- fMP4: the container is CMAF, as defined in {{cmaf-containers}}.
- MPEG-2 TS: a Chunk is a 188-byte packet; a random-access point includes the PAT/PMT. The container is self-initializing.
- Packed audio and WebVTT: these containers define no Chunks; the Segment start is the random-access point. The containers are self-initializing.

# Security Considerations {#security}

The mapping inherits the security properties of MOQT {{MoQTransport}}.

## Relay-Visible Metadata

Relays observe Full Track Names, Group/Object structure, and unencrypted Properties, including the paths in `HAS_ORIGINAL_REFERENCE` ({{original-reference}}). A source whose Request Paths carry credentials exposes them to every relay. The `fallbackOrigin` field ({{mapping-manifest}}) exposes the origin URL to every relay and Subscriber.

## Denial of Service

TODO (WG discussion): this section needs a full analysis. Candidate risk areas include relay resource exhaustion from a Publisher's freedom to split a Segment into arbitrarily many small Objects ({{packaging}}), and cache-warming amplification from unauthenticated SUBSCRIBE_TRACKS requests with the FORWARD parameter equal to 0 against the Presentation namespace ({{warmup}}; {{Section 13.1 of MoQTransport}}, {{Section 13.7.2 of MoQTransport}}).

# IANA Considerations {#iana}

IANA is requested to create the "HAS-o-MoQT Format Flavors" registry, registration policy Specification Required ({{Section 4.6 of RFC8126}}), with fields Flavor and Reference, initially:

| Flavor | Reference |
|--------|-----------|
| `dash` | {{dash}} of this document |
| `hls`  | {{hls}} of this document |

Property codepoints need no registry ({{codepoints}}).

--- back

# Egress Gateway Operation {#egress-operation}

This appendix is informative.

## Configuration {#egress-config}

An Egress Gateway is configured out of band to map an incoming HTTP request onto a MOQT Location:

- Scope: the HTTP authority (host) selects the relay or origin the gateway connects to.
- Path: the Request Path is split, by a preconfigured rule, into a Root Path selecting a Presentation Track Namespace and the remainder ({{addressing}}).

## Serving a Request

On an HTTP request the gateway:

1. Resolves the authority to a MOQT connection and connects if not already connected.
2. Splits the Request Path into (namespace, remainder) per configuration.
3. Subscribes to the Presentation's Mapping Manifest Track (if not already) and reads the Track bindings and `initRef` values; for a Track with an Index Track, subscribes to it.
4. Classifies the remainder using the Mapping Manifest and responds ({{egress}}):
   - Manifest, delta or blocking request: per the gateway's profile ({{egress-profiles}}).
   - Initialization Data: {{init}}.
   - Media Segment: an HTTP byte-range request is honored by computing Object offsets within the Segment ({{packaging}}).

## Choosing the Retrieval Mode

The gateway chooses among the retrieval modes of {{live-edge}} by the Segment's position relative to the live edge: FETCH behind it; SUBSCRIBE with FILL_PARAMETERS at or just behind it, when the client will keep playing forward.

## Subscription Lifecycle and Cache

- The gateway keeps its Mapping Manifest subscription for a namespace alive as long as requests into that namespace continue, and drops it after an idle timeout.
- Retrieved Objects are cached keyed by Full Track Name, Group ID and Object ID and reused across HTTP requests, as a relay cache would.

## Warming Up {#warmup}

Before serving the first request into a Presentation the gateway subscribes to and parses the Mapping Manifest ({{mapping-manifest}}), one upstream round trip. Ahead of demand, a gateway may issue SUBSCRIBE_TRACKS ({{Section 10.20 of MoQTransport}}) over the Presentation namespace or one of its sub-namespaces ({{namespaces}}) with the FORWARD parameter ({{Section 10.2.18 of MoQTransport}}) equal to 0; the gateway learns each Media Stream Track's Initialization Data (a Track Property) and the versions on the Mapping Manifest Track before any Object is requested.

# Examples {#examples}

This appendix is informative.

One live Presentation, carried as both DASH ({{dash}}) and HLS ({{hls}}) from the same Segments:

- `video-1080p`, `video-720p`, `audio-en`: referenced by both Formats' Manifests.
- `audio-cs`, `sub-en`: referenced by the HLS Manifests only.

## Mapping Manifest {#example-mapping-manifest}

The full document (Object 0 of a Group). It exercises:

- addressing scheme `template` ({{addressing}}) plain (`audio-en`), zero-padded (`video-1080p`), and with a `$$` literal on a Track begun by a numbering restart, its `startGroup` continuing the timeline (`sub-en`).
- scheme `time` (`video-720p`).
- scheme `index` with its Index Track (`audio-cs`, {{example-index-track}}).
- Initialization Data as a Track Property, inline, and absent for a self-initializing container (`sub-en`).
- the Delta Track extension ({{delta-extension}}) with `lowLatency` (the MPD, the 1080p playlist), without it (the 720p playlist), and Manifests without a Delta Track.

~~~ json
{
  "generatedAt": 1788742800000,
  "isLive": true,
  "manifests": [
    { "flavor": "dash", "path": "manifest.mpd",
      "snapshotTrack": "manifest.mpd",
      "extension": { "deltaTrack": "manifest.mpd.patch",
        "lowLatency": { "patchLocation": {
          "path": "manifest.mpd.patch", "ttl": 60 } } },
      "media": [
        { "track": "video-1080p", "representationId": "v1080",
          "adaptationSetId": "1", "periodId": "p0" },
        { "track": "video-720p", "representationId": "v720",
          "adaptationSetId": "1", "periodId": "p0" },
        { "track": "audio-en", "representationId": "a-en",
          "adaptationSetId": "2", "periodId": "p0" }
      ] },
    { "flavor": "hls", "path": "master.m3u8",
      "snapshotTrack": "master.m3u8" },
    { "flavor": "hls", "path": "video/1080p/media.m3u8",
      "snapshotTrack": "video/1080p/media.m3u8",
      "extension": { "deltaTrack": "video/1080p/media.m3u8.delta",
        "lowLatency": { "serverControl":
      "CAN-BLOCK-RELOAD=YES,PART-HOLD-BACK=1.0,CAN-SKIP-UNTIL=24.0"
        } },
      "media": [ { "track": "video-1080p",
        "mediaPlaylistPath": "video/1080p/media.m3u8" } ] },
    { "flavor": "hls", "path": "video/720p/media.m3u8",
      "snapshotTrack": "video/720p/media.m3u8",
      "extension": { "deltaTrack": "video/720p/media.m3u8.delta" },
      "media": [ { "track": "video-720p",
        "mediaPlaylistPath": "video/720p/media.m3u8" } ] },
    { "flavor": "hls", "path": "audio/en/media.m3u8",
      "snapshotTrack": "audio/en/media.m3u8",
      "media": [ { "track": "audio-en",
        "mediaPlaylistPath": "audio/en/media.m3u8" } ] },
    { "flavor": "hls", "path": "audio/cs/media.m3u8",
      "snapshotTrack": "audio/cs/media.m3u8",
      "media": [ { "track": "audio-cs",
        "mediaPlaylistPath": "audio/cs/media.m3u8" } ] },
    { "flavor": "hls", "path": "sub/en/media.m3u8",
      "snapshotTrack": "sub/en/media.m3u8",
      "media": [ { "track": "sub-en",
        "mediaPlaylistPath": "sub/en/media.m3u8" } ] }
  ],
  "tracks": [
    { "name": "video-1080p", "initRef": "init-v1080",
      "addressing": { "scheme": "template",
        "template": "video/1080p/seg-$Number%05d$.m4s",
        "startNumber": 1, "startGroup": 0 } },
    { "name": "video-720p", "initRef": "init-v720",
      "addressing": { "scheme": "time",
        "template": "video/720p/seg-$Time$.m4s",
        "startTime": 900000, "duration": 180000, "startGroup": 0 } },
    { "name": "audio-en", "initRef": "init-a-en",
      "addressing": { "scheme": "template",
        "template": "audio/en/seg-$Number$.m4s",
        "startNumber": 1, "startGroup": 0 } },
    { "name": "audio-cs", "initRef": "init-a-cs",
      "addressing": { "scheme": "index",
        "indexTrack": "audio-cs-index" } },
    { "name": "sub-en",
      "addressing": { "scheme": "template",
        "template": "sub/en/seg$$-$Number$.vtt",
        "startNumber": 0, "startGroup": 3600 } }
  ],
  "initDataList": [
    { "id": "init-v1080", "type": "track-property", "data": "0x0D",
      "path": "video/1080p/init.mp4",
      "headers": { "content-type": "video/mp4" } },
    { "id": "init-v720", "type": "track-property", "data": "0x0D",
      "path": "video/720p/init.mp4",
      "headers": { "content-type": "video/mp4" } },
    { "id": "init-a-en", "type": "track-property", "data": "0x0F",
      "path": "audio/en/init.mp4",
      "headers": { "content-type": "audio/mp4" } },
    { "id": "init-a-cs", "type": "inline",
      "data": "AAAAGGZ0eXBjbWZjAAAAAGNtZmNpc282",
      "path": "audio/cs/init.mp4",
      "headers": { "content-type": "audio/mp4" } }
  ]
}
~~~

## Mapping Manifest Updates {#example-mapping-updates}

Three update documents ({{mapping-updates}}): the later Objects of the same Group, applied in order.

Object 1 adds a German audio rendition: the `initDataList` entry first, the `tracks` entry as a `clone` of `audio-en` with its `initRef` ({{mapping-manifest}}), the new HLS `manifests` entry, and the MPD entry's new `media` binding as a `remove` plus `add` of the entry:

~~~ json
{
  "deltaUpdate": [
    { "op": "add", "initDataList": [
        { "id": "init-a-de", "type": "track-property",
          "data": "0x0F", "path": "audio/de/init.mp4",
          "headers": { "content-type": "audio/mp4" } } ] },
    { "op": "clone", "tracks": [
        { "name": "audio-de", "parentName": "audio-en",
          "initRef": "init-a-de",
          "addressing": { "scheme": "template",
            "template": "audio/de/seg-$Number$.m4s",
            "startNumber": 1, "startGroup": 0 } } ] },
    { "op": "remove", "manifests": [ { "path": "manifest.mpd" } ] },
    { "op": "add", "manifests": [
        { "flavor": "dash", "path": "manifest.mpd",
          "snapshotTrack": "manifest.mpd",
          "extension": { "deltaTrack": "manifest.mpd.patch",
            "lowLatency": { "patchLocation": {
              "path": "manifest.mpd.patch", "ttl": 60 } } },
          "media": [
            { "track": "video-1080p", "representationId": "v1080",
              "adaptationSetId": "1", "periodId": "p0" },
            { "track": "video-720p", "representationId": "v720",
              "adaptationSetId": "1", "periodId": "p0" },
            { "track": "audio-en", "representationId": "a-en",
              "adaptationSetId": "2", "periodId": "p0" },
            { "track": "audio-de", "representationId": "a-de",
              "adaptationSetId": "3", "periodId": "p0" }
          ] },
        { "flavor": "hls", "path": "audio/de/media.m3u8",
          "snapshotTrack": "audio/de/media.m3u8",
          "media": [ { "track": "audio-de",
            "mediaPlaylistPath": "audio/de/media.m3u8" } ] } ] }
  ]
}
~~~

Object 2 gives the English audio playlist a Delta Track, again as a `remove` plus `add`:

~~~ json
{
  "deltaUpdate": [
    { "op": "remove", "manifests": [
        { "path": "audio/en/media.m3u8" } ] },
    { "op": "add", "manifests": [
        { "flavor": "hls", "path": "audio/en/media.m3u8",
          "snapshotTrack": "audio/en/media.m3u8",
          "extension": { "deltaTrack": "audio/en/media.m3u8.delta",
            "lowLatency": { "serverControl":
              "CAN-BLOCK-RELOAD=YES,CAN-SKIP-UNTIL=12.0" } },
          "media": [ { "track": "audio-en",
            "mediaPlaylistPath": "audio/en/media.m3u8" } ] } ] }
  ]
}
~~~

Object 3 ends the commentary audio; a `remove` entry holds only its `path`, `name` or `id`:

~~~ json
{
  "deltaUpdate": [
    { "op": "remove", "manifests": [
        { "path": "audio/cs/media.m3u8" } ] },
    { "op": "remove", "tracks": [ { "name": "audio-cs" } ] },
    { "op": "remove", "initDataList": [ { "id": "init-a-cs" } ] }
  ]
}
~~~

## Index Track {#example-index-track}

The full document (Object 0 of a Group) of `audio-cs-index` ({{index-document}}). The commentary Segments are byte ranges of one resource:

~~~ json
{
  "bindings": [
    { "group": 0, "path": "audio/cs/media.mp4", "range": "912-165423" },
    { "group": 1, "path": "audio/cs/media.mp4", "range": "165424-329871" },
    { "group": 2, "path": "audio/cs/media.mp4", "range": "329872-494319" }
  ]
}
~~~

An update document ({{index-updates}}), appending the next Segment, a whole file without `range`:

~~~ json
{
  "bindings": [
    { "group": 3, "path": "audio/cs/seg-0003.m4s" }
  ]
}
~~~

# Acknowledgments
{:numbered="false"}

TODO: acknowledge contributors.

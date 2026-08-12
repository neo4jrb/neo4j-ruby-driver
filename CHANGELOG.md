# Changelog

All notable changes to this project are documented in this file, generated from
the commit history with [git-cliff](https://git-cliff.org) — regenerate with
`rake changelog`.

The format follows [Keep a Changelog](https://keepachangelog.com). The gem
version tracks the neo4j-java-driver version it targets, with a RubyGems
pre-release token when applicable (e.g. `6.2.1.beta.1`).

## [Unreleased]

### Added

- Expose BookmarkManager + testkit support ([#317](https://github.com/neo4jrb/neo4j-ruby-driver/pull/317))
- Implement AuthTokenManager + per-session auth ([#342](https://github.com/neo4jrb/neo4j-ruby-driver/pull/342))
- Wire Backend:MockTime via Internal::Clock seam + TestkitClock ([#344](https://github.com/neo4jrb/neo4j-ruby-driver/pull/344))
- Support max_connection_lifetime config → Feature:API:Driver:MaxConnectionLifetime ([#345](https://github.com/neo4jrb/neo4j-ruby-driver/pull/345))
- Mutual-TLS client certificates → Feature:API:SSLClientCertificate ([#348](https://github.com/neo4jrb/neo4j-ruby-driver/pull/348))
- Emit gqlStatusObjects in summary (jruby) ([#370](https://github.com/neo4jrb/neo4j-ruby-driver/pull/370))
- Complete Backend:RTFetch — routing-table fetch + driver-wrapper error codes ([#375](https://github.com/neo4jrb/neo4j-ruby-driver/pull/375))
- Stop advertising Feature:API:Driver.VerifyConnectivity ([#380](https://github.com/neo4jrb/neo4j-ruby-driver/pull/380))
- Serialize GQL error cause chain + classification default ([#382](https://github.com/neo4jrb/neo4j-ruby-driver/pull/382))
- Advertise Feature:API:Driver.ExecuteQuery:WithAuth on JRuby ([#385](https://github.com/neo4jrb/neo4j-ruby-driver/pull/385))
- Advertise Feature:API:RetryableExceptions on JRuby ([#386](https://github.com/neo4jrb/neo4j-ruby-driver/pull/386))
- Advertise Feature:IdempotentRetries on JRuby ([#387](https://github.com/neo4jrb/neo4j-ruby-driver/pull/387))
- Advertise Feature:API:Session:NotificationsConfig on JRuby ([#388](https://github.com/neo4jrb/neo4j-ruby-driver/pull/388))
- Sans-I/O core + pluggable pump + bounded record buffer ([#396](https://github.com/neo4jrb/neo4j-ruby-driver/pull/396))
- Promote public streaming path onto the prefetch pump ([#397](https://github.com/neo4jrb/neo4j-ruby-driver/pull/397))
- GQL-status errors (Bolt 5.7) — parse + synthesise ([#400](https://github.com/neo4jrb/neo4j-ruby-driver/pull/400))
- Raise TransactionTerminatedException after tx termination ([#401](https://github.com/neo4jrb/neo4j-ruby-driver/pull/401))
- Dedicated per-connection reader; unified async pipeline (step 2) ([#404](https://github.com/neo4jrb/neo4j-ruby-driver/pull/404))
- Incremental record streaming with a shared record/promise wait ([#405](https://github.com/neo4jrb/neo4j-ruby-driver/pull/405))
- Qid multiplexing for concurrent results in explicit transactions ([#406](https://github.com/neo4jrb/neo4j-ruby-driver/pull/406))
- Send Bolt TELEMETRY reports (driver-API usage) ([#407](https://github.com/neo4jrb/neo4j-ruby-driver/pull/407))
- Implement Backend:MockTime (injectable clock seam) ([#408](https://github.com/neo4jrb/neo4j-ruby-driver/pull/408))
- Connection-pool metrics — Feature:API:Liveness.Check drop_connections ([#412](https://github.com/neo4jrb/neo4j-ruby-driver/pull/412))
- Driver-level NotificationsConfig → HELLO [Feature:API:Driver:NotificationsConfig] ([#415](https://github.com/neo4jrb/neo4j-ruby-driver/pull/415))
- Session-level NotificationsConfig on BEGIN/RUN [Feature:API:Session:NotificationsConfig] ([#421](https://github.com/neo4jrb/neo4j-ruby-driver/pull/421))
- Default bookmark manager for execute_query [Feature:API:Driver.ExecuteQuery] ([#423](https://github.com/neo4jrb/neo4j-ruby-driver/pull/423))
- Advertise Optimization:PullPipelining ([#425](https://github.com/neo4jrb/neo4j-ruby-driver/pull/425))
- Bolt 4.3/4.4 UTC patch + full temporal types [Feature:Bolt:Patch:UTC, Feature:API:Type.Temporal] ([#427](https://github.com/neo4jrb/neo4j-ruby-driver/pull/427))
- Per-query auth for execute_query [Feature:API:Driver.ExecuteQuery:WithAuth] ([#429](https://github.com/neo4jrb/neo4j-ruby-driver/pull/429))
- Advertise Feature:API:RetryableExceptions ([#430](https://github.com/neo4jrb/neo4j-ruby-driver/pull/430))
- Surface Bolt 6.0 UnsupportedType [Feature:API:Type.UnsupportedType] ([#428](https://github.com/neo4jrb/neo4j-ruby-driver/pull/428))
- Backfill GQL status objects for pre-5.6 servers [Feature:API:Summary:GqlStatusObjects] ([#431](https://github.com/neo4jrb/neo4j-ruby-driver/pull/431))
- Pipeline BEGIN+RUN+PULL in execute_query [Optimization:ExecuteQueryPipelining] ([#432](https://github.com/neo4jrb/neo4j-ruby-driver/pull/432))
- Result#to_a pulls all records in one PULL -1 [Optimization:ResultListFetchAll] ([#434](https://github.com/neo4jrb/neo4j-ruby-driver/pull/434))
- Honour connection.recv_timeout_seconds hint [ConfHint:connection.recv_timeout_seconds] ([#433](https://github.com/neo4jrb/neo4j-ruby-driver/pull/433))
- Retry idempotent auto-commit RUN once [Feature:IdempotentRetries] ([#435](https://github.com/neo4jrb/neo4j-ruby-driver/pull/435))
- Pipeline re-auth LOGOFF+LOGON [Optimization:AuthPipelining] ([#437](https://github.com/neo4jrb/neo4j-ruby-driver/pull/437))
- Advertise Optimization:ImplicitDefaultArguments ([#438](https://github.com/neo4jrb/neo4j-ruby-driver/pull/438))
- Optimistic home-database cache [Optimization:HomeDatabaseCache] ([#436](https://github.com/neo4jrb/neo4j-ruby-driver/pull/436))
- Mutual-TLS client certificates [Feature:API:SSLClientCertificate] ([#439](https://github.com/neo4jrb/neo4j-ruby-driver/pull/439))
- Reject scheme+manual security config [Detail:DefaultSecurityConfigValueEquality] ([#440](https://github.com/neo4jrb/neo4j-ruby-driver/pull/440))
- Preserve absent profile stats [Feature:API:Summary:Profile:OptionalStats] ([#442](https://github.com/neo4jrb/neo4j-ruby-driver/pull/442))
- Bolt 6.1 + UUID type [Feature:Bolt:6.1, Feature:API:Type.UUID] ([#443](https://github.com/neo4jrb/neo4j-ruby-driver/pull/443))

### Changed

- Fix Summary payload + advertise honest features (33 → 42 pass)
- Refactor into per-request classes with Data.define
- Managed transactions implementation
- Drop "driver-side hook" — driver already does the right thing
- Thread Connection through to Request handlers
- Implement managed transactions (+19 pass, −56 errors)
- Exclude env-dependent test_address from baseline
- Encode CypherNode / Relationship / Path in record values (+7 pass)
- Simplify timeout_to_milliseconds
- Endless-method form for timeout_to_milliseconds
- Correct rescue-chain claim, add Ruby-block-into-Java direction
- Renumber backlog after duplicate #13
- Lib/{shared,mri,jruby} layout + Pattern 1 staged-build
- Address PR #19 review
- Bump JRuby matrix from 9.4 to 10.1.0.0
- Add MRI-on-JRuby flavor row exercising force_ruby_platform
- Drop sudo from `npm install -g claude-code` ([#287](https://github.com/neo4jrb/neo4j-ruby-driver/pull/287))
- Pass glob: with name: in the FORCE_MRI branch ([#290](https://github.com/neo4jrb/neo4j-ruby-driver/pull/290))
- Complete protocol surface for JRuby work ([#292](https://github.com/neo4jrb/neo4j-ruby-driver/pull/292))
- Add Dockerfile + testkit.json (standard driver glue) ([#303](https://github.com/neo4jrb/neo4j-ruby-driver/pull/303))
- Port missing tests from neo4j-java-driver SessionIT ([#323](https://github.com/neo4jrb/neo4j-ruby-driver/pull/323))
- Advertise all 'a'-only features on JRuby ([#339](https://github.com/neo4jrb/neo4j-ruby-driver/pull/339))
- Add per-impl flaky-skip section ([#340](https://github.com/neo4jrb/neo4j-ruby-driver/pull/340))
- Port from neo4j-java-driver DriverCloseIT ([#334](https://github.com/neo4jrb/neo4j-ruby-driver/pull/334))
- Address Copilot review comments from #323 ([#329](https://github.com/neo4jrb/neo4j-ruby-driver/pull/329))
- Port shouldGetSystemUpdates from neo4j-java-driver SummaryIT ([#333](https://github.com/neo4jrb/neo4j-ruby-driver/pull/333))
- Port missing tests from neo4j-java-driver TransactionIT ([#330](https://github.com/neo4jrb/neo4j-ruby-driver/pull/330))
- Port sync tests from QueryRunnerCloseIT ([#336](https://github.com/neo4jrb/neo4j-ruby-driver/pull/336))
- Port small ITs (QueryIT + ResolverIT) — argument-validation + resolver-failure ([#335](https://github.com/neo4jrb/neo4j-ruby-driver/pull/335))
- Port missing tests from CredentialsIT ([#338](https://github.com/neo4jrb/neo4j-ruby-driver/pull/338))
- Port missing tests from neo4j-java-driver ErrorIT ([#331](https://github.com/neo4jrb/neo4j-ruby-driver/pull/331))
- Bump neo4j-java-driver 6.0.3 → 6.1.0 + testkit to latest 6.x ([#347](https://github.com/neo4jrb/neo4j-ruby-driver/pull/347))
- Skip test_custom_resolver on all flavours ([#354](https://github.com/neo4jrb/neo4j-ruby-driver/pull/354))
- Sync feature list with testkit + neo4j-java-driver ([#355](https://github.com/neo4jrb/neo4j-ruby-driver/pull/355))
- Bolt 3.0 + routing discovery foundation (+131 stub tests) ([#352](https://github.com/neo4jrb/neo4j-ruby-driver/pull/352))
- Chain cause at non-raise exception-mapping sites ([#364](https://github.com/neo4jrb/neo4j-ruby-driver/pull/364))
- Error classification — TokenExpired + routed SessionExpired (+33 stub) ([#359](https://github.com/neo4jrb/neo4j-ruby-driver/pull/359))
- Behavioral tail — rollback failure surfaced + negative timeout (+7) ([#365](https://github.com/neo4jrb/neo4j-ruby-driver/pull/365))
- Managed auth-token-manager foundation + tx-end result discard ([#367](https://github.com/neo4jrb/neo4j-ruby-driver/pull/367))
- Explicit-tx BEGIN mode + eager begin — managed-auth error-on-begin [WIP] ([#372](https://github.com/neo4jrb/neo4j-ruby-driver/pull/372))
- AuthorizationExpiredTreatment (phase B) ([#374](https://github.com/neo4jrb/neo4j-ruby-driver/pull/374))
- Complete Feature:Auth:Managed error handling ([#379](https://github.com/neo4jrb/neo4j-ruby-driver/pull/379))
- Finish Feature:Auth:Managed — session-auth notify, token rotation, authz-expired treatment ([#381](https://github.com/neo4jrb/neo4j-ruby-driver/pull/381))
- Close the routing stub-conformance gap ([#384](https://github.com/neo4jrb/neo4j-ruby-driver/pull/384))
- Drop redundant ThreadHandle from Executor ([#399](https://github.com/neo4jrb/neo4j-ruby-driver/pull/399))
- Extract Connection#advance (colorless pump step) [pipeline step 1] ([#403](https://github.com/neo4jrb/neo4j-ruby-driver/pull/403))
- Polymorphic Bolt protocol versions, drop version-comparison checks ([#422](https://github.com/neo4jrb/neo4j-ruby-driver/pull/422))
- Hoist shared hello_extra to Base; de-dup at second occurrence ([#426](https://github.com/neo4jrb/neo4j-ruby-driver/pull/426))
- Bump java-driver 6.2.0 + CI; sync get_features; flavor-agnostic Types::UUID ([#441](https://github.com/neo4jrb/neo4j-ruby-driver/pull/441))
- Bump rspec to latest; de-duplicate dev deps ([#445](https://github.com/neo4jrb/neo4j-ruby-driver/pull/445))
- Remove dead async API; drop concurrent-ruby-edge runtime dep ([#449](https://github.com/neo4jrb/neo4j-ruby-driver/pull/449))

### Fixed

- Check STAGED_BUILD == '1' explicitly to avoid false positives
- Guard backtrace_locations + enable Type.Temporal on jruby ([#341](https://github.com/neo4jrb/neo4j-ruby-driver/pull/341))
- Defer wire errors from Bolt::Connection#flush ([#328](https://github.com/neo4jrb/neo4j-ruby-driver/pull/328))
- JRuby temporal errors — update conversion/decoders to refactored Types ([#353](https://github.com/neo4jrb/neo4j-ruby-driver/pull/353))
- Classify raw transport errors from Connection#connect ([#356](https://github.com/neo4jrb/neo4j-ruby-driver/pull/356))
- Restore GetRoutingTable for the 6.x bolt-connection API ([#358](https://github.com/neo4jrb/neo4j-ruby-driver/pull/358))
- Single-reader command loop — fixes routing auth-callback hang ([#360](https://github.com/neo4jrb/neo4j-ruby-driver/pull/360))
- Align divergent subclass exceptions with Java (+ pin testkit to fork) ([#361](https://github.com/neo4jrb/neo4j-ruby-driver/pull/361))
- Datatypes — unknown timezones, unsupported types, DST packing ([#366](https://github.com/neo4jrb/neo4j-ruby-driver/pull/366))
- Session auth token dropped (authorizationToken field) ([#368](https://github.com/neo4jrb/neo4j-ruby-driver/pull/368))
- Emit ProfiledPlan#records as "rows" in profile shape ([#371](https://github.com/neo4jrb/neo4j-ruby-driver/pull/371))
- Omit BEGIN mode for managed write transactions ([#376](https://github.com/neo4jrb/neo4j-ruby-driver/pull/376))
- Send BookmarkManager bookmarks on tx BEGIN — complete Feature:API:BookmarkManager ([#378](https://github.com/neo4jrb/neo4j-ruby-driver/pull/378))
- Reject routing params on bolt:// — complete server_side_routing feature ([#377](https://github.com/neo4jrb/neo4j-ruby-driver/pull/377))
- Make Driver#verify_authentication routing-aware ([#389](https://github.com/neo4jrb/neo4j-ruby-driver/pull/389))
- Populate ResultSummary#gql_status_objects on Bolt 5.6+ ([#391](https://github.com/neo4jrb/neo4j-ruby-driver/pull/391))
- Driver#encrypted? reads the wrong option key (:encrypted) ([#392](https://github.com/neo4jrb/neo4j-ruby-driver/pull/392))
- Don't fabricate trust_system_certificates, so +ssc trusts all ([#393](https://github.com/neo4jrb/neo4j-ruby-driver/pull/393))
- Resolve home database per session (home-db + routing-liveness parity) ([#409](https://github.com/neo4jrb/neo4j-ruby-driver/pull/409))
- Verify_connectivity RESET probe — Feature:API:Driver.VerifyConnectivity to green ([#410](https://github.com/neo4jrb/neo4j-ruby-driver/pull/410))
- Acquisition timeout bounds the TCP connect — Feature:API:ConnectionAcquisitionTimeout to green ([#411](https://github.com/neo4jrb/neo4j-ruby-driver/pull/411))
- Retry classification + write-failover reuse — Feature:Bolt:4.3 retry to green ([#413](https://github.com/neo4jrb/neo4j-ruby-driver/pull/413))
- Discard the connection when the pool-return RESET fails ([#414](https://github.com/neo4jrb/neo4j-ruby-driver/pull/414))
- Count testkit failures when stderr splits unittest's summary line ([#416](https://github.com/neo4jrb/neo4j-ruby-driver/pull/416))
- Inherit driver-level fetch_size when a session leaves it nil [Feature:Bolt:4.2] ([#417](https://github.com/neo4jrb/neo4j-ruby-driver/pull/417))
- Raise IllegalStateException on closed-driver home-db routing [Feature:Bolt:3.0] ([#418](https://github.com/neo4jrb/neo4j-ruby-driver/pull/418))
- Re-consult auth manager on Bolt 5.0 routed re-auth [Feature:Auth:Managed] ([#419](https://github.com/neo4jrb/neo4j-ruby-driver/pull/419))

[unreleased]: https://github.com/neo4jrb/neo4j-ruby-driver/commits/main

<!-- generated by git-cliff -->

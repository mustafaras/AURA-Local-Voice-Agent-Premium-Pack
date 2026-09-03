# SP-032 Neden Blocked Kalıyor — Net Sebepler

- **Tarih:** 2026-09-03
- **Kaynak:** kanonik `beta-readiness.json`, `SECOND_PASS_OPEN_GAPS.md` OPEN-14,
  `RISK_REGISTER.md`, ADR-047/049/051/052; `HEAD == origin/main == e7d67a7`.
- **Durum:** SP-032 `blocked`; `beta-readiness.json` `readiness_status: blocked`;
  `release_candidate.status: blocked`, `approved: false`.

## Özet

SP-032 (FINAL acceptance) yalnızca **tüm** aşağıdaki postcondition'lar geçtikten
sonra `release_candidate_verified` / `released` durumuna geçebilir. Bunların
hiçbiri tek bir yerel oturumda meşru şekilde kapatılamaz; fabrikasyon yasaktır
(ADR-051/052, kontrol kontratı). Bu yüzden SP-032 `blocked` kalır.

## Net sebepler (kanıtlanmış)

| # | Blocker | Kanıt / kaynak | Neden kapatılamıyor |
|---|---|---|---|
| 1 | **R11 tamamlanmadı** | `beta-readiness.json` `dependency_gate`: `r11_state: in_progress`, `r11_release_status: development_unverified`, `r11_completion_required: true` | Canlı lifecycle gate'leri (sleep/wake/crash recovery, dolu-profil migration, safe-mode/support-bundle canlı gözlem) yalnızca unit-testli (`AuraLifecycleTests` 48/10/0), canlı değil |
| 2 | **Canlı beta SLO'ları ölçülmedi** | `open_blockers`: `ptt_ack`, `stt_partial`, `dialogue_first_token` | Canlı mikrofonlu kullanıcı-beta penceresi gerektirir; ölçülmedi |
| 3 | **Canlı STT/WER ölçülmedi** | `open_blockers` | Konuşabilen bir operatör gerektirir; yalnızca sentetik-speech accommodation var, canlı mikrofon WER yok |
| 4 | **Senaryo matrisi canlı çalıştırılmadı** | `open_blockers` | Yalnızca `deterministic_harness` sınıfı; canlı beta penceresinde hiç çalıştırılmadı |
| 5 | **Incident review yok** | `open_blockers` | Beta penceresi olmadığı için üretilecek incident yok; review çalışmadı |
| 6 | **R12 sign-off'ları canlı kanıtın yerine geçmez** | `open_blockers` | 5 sign-off kayıtlı ama dışlanmış canlı-beta SLO/senaryo/incident/R11 kanıtının yerini tutmaz; local-only scope readiness'i `blocked` tutar |
| 7 | **Telemetri kapalı** | `telemetry.enabled: false`, `transport: none` | Canlı beta ölçümü `telemetry_or_beta` yetkisi gerektirir; yalnızca owner açabilir |
| 8 | **Developer ID / notarization / harici dağıtım** | ADR-049 | Kalıcı olarak kapsam dışı; `release_candidate`'in `blocked` kalmasını sağlar |
| 9 | **FINAL authority yok** | SP-032 prompt gate | SP-032 `release_candidate_verified` / `released` durumuna geçmek için FINAL yetkisi gerektirir; verilmedi |

## Sonuç

- `beta-readiness.json` `readiness_status: blocked`
- `release_candidate.status: blocked`, `approved: false`
- SP-033 başlatılmadı
- Yerel canlı kabul (`EV-SP-032-20260903-LIVE-ACCEPTANCE-01`) gate'leri
  **ilerletti** ama yukarıdaki yapısal gate'leri kapatmadı; dürüstçe `open`
  bırakıldı.

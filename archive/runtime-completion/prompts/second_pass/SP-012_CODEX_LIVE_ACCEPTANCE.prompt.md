# SP-012 → LIVE ACCEPTANCE — Codex Execution Prompt

Bu prompt, SP-012'nin kalan tek adımı olan **canlı uçtan uca kabulü** (live acceptance)
tamamlaman içindir. Deterministic/source-side kısım tamamlandı ve push edildi
(commit `27e9b78`). Senin görevin: **`.vsix`'i VS Code'a kurmak, shared secret'i
iki tarafa yazmak ve canlı authenticated round trip'i kanıtlamak.**

---

## 0. Bağlam ve durum

- **Prompt:** SP-012 — Authenticated VS Code Extension Bridge (OPEN-07 / R6).
- **Mevcut durum:** `in_progress` / `blocked`. Deterministic taraf bitmiş: extension paketlendi,
  AURA provisioning yolu eklendi, 31/31 + 23/23 test geçti, validator PASSED.
- **Neden blocked:** canlı kanıt yok. `.vsix` VS Code'a kurulmadı, shared secret iki tarafa
  yansıtılmadı, canlı authenticated round trip koşulmadı.
- **Kommit (HEAD):** `27e9b78` on `main`, `origin/main` ile senkron (push edildi).
- **ADR-041:** `docs/decisions/ADR-041-vscode-extension-bridge.md` — **Accepted**.
- **Evidence:** `AURA_RUNTIME_COMPLETION/state/EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01.md`.

### Kilit dosyalar
- Extension paketi: `AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix` (SHA-256
  `d7a9072e46cfe9cca13973bb4419ecba7875b38db026fdd51f75bae9035f2075`).
- AURA provisioning API: `Sources/AURA/AuraKernel_RuntimeAPI.swift` → `provisionVSCodeBridge(sharedSecret:extensionID:)`,
  `revokeVSCodeBridge(extensionID:)`, `vscodeBridgeProvisioned()`.
- AURA secret store: `Sources/AuraVSCode/VSCodeBridgeSecretStore.swift`.
- Extension source: `AuraVSCodeExtension/src/*.ts`.
- README: `AuraVSCodeExtension/README.md` (paketleme/provisioning/protocol anlatır).

---

## 1. Yetki / Hard Boundaries

Bu prompt, canlı kabul için **explicit authority** verir (ve sen de kullanıcıya soracaksın):

- ✅ **install**: `code --install-extension <vsix>` — **izinli**.
- ✅ **launch / run**: AURA'yı ve VS Code'u çalıştırmak — **izinli**.
- ✅ **secret provisioning**: AURA tarafına `provisionVSCodeBridge` çağrısı ve VS Code tarafına
  `AURA Bridge: Enter Shared Secret` ile aynı secret'ı girmek — **izinli**.
- ✅ **Kernel/extension değişikliği**: yalnızca kabulü etkileyen sınırlı düzeltmeler — **izinli**.
- ❌ **commit/push/merge**: **yapma** — kullanıcı bu işi yapar.
- ❌ **release/publish/notarize**: yapma.
- ❌ **provider account / TCC / telemetry / beta enrollment**: yapma.

> **Kullanıcı varlığı şart:** VS Code tarafındaki `showInputBox` prompt'una secret girilecek.
> Bu, secret'in senin (veya asistanın) gözünden geçmesi demektir. Bu nedenle:
> - Secret'i kendin üreteceksen, bunu **kullanıcıya sorarak** yap; kullanıcı yoksa **secret üretme**.
> - Kullanıcı secret'i iki tarafa da girecekse, sen sadece akışı gözlemle/kanıtla.

---

## 2. Procedure — Adım Adım

### Adım 1 — Extension'ı kur
```bash
code --install-extension AuraVSCodeExtension/aura-vscode-extension-0.1.0.vsix --force
```
Doğrula: `code --list-extensions | grep aura` → `aura.aura-vscode-extension`.

### Adım 2 — Üç bridge path ayarla (VS Code settings.json)
Aşağıdakileri VS Code ayarlarına ekle (hem app hem extension erişebilir bir dizine):

```json
{
  "auraBridge.statePath": "<shared>/vscode-state.json",
  "auraBridge.commandPath": "<shared>/vscode-command.json",
  "auraBridge.responsePath": "<shared>/vscode-response.json",
  "auraBridge.extensionID": "ai.aura.vscode-bridge"
}
```
> `<shared>` örneğin `~/Library/Application Support/AURA/vscode-bridge` veya bir temp dizin olabilir.
> Extension `ensureParentDir` ile dizini otomatik oluşturur.

### Adım 3 — Shared secret'i iki tarafa eşleştir
Bir secret belirle (≥16 karakter). **İki tarafa da aynı değeri gir:**

1. **AURA tarafı:** `provisionVSCodeBridge(sharedSecret:secret, extensionID:"your-aura-extension-id")`
   çağrısı ile Keychain'e yaz.
   - Not: AURA'nın `configuration.vscode.extensionID` değeri **aynı** olmalı; aksi halde `permissionDenied`.
   - AURA'yi ayarlarında `extensionID`'yi "your-aura-extension-id" yap.
2. **VS Code tarafı:** Command Palette → `AURA Bridge: Enter Shared Secret` → aynı secret'i gir.

### Adım 4 — Canlı authenticated round trip
- AURA'nın `vscodeBridgeHealth` yeteneğinin `.ready` olduğunu doğrula.
- Bir editor/task/diagnostic okuma veya `runTask` komutuyla canlı round trip gerçekleştir.
- Aşağıdaki failure-mode'ları canlı koş (her biri için kanıt):
  - **disconnect** — extension'ı kapat, health `.disconnected` olmalı.
  - **version mismatch** — protocol versiyonunu boz, `.versionMismatch`/`.disabled` olmalı.
  - **replay** — aynı command nonce'u tekrar gönder, reddedilmeli.
  - **stale editor** — bayat snapshot okunmalı/reddedilmeli.
  - **dirty buffer** — confirmation denial ürettirmeli.
  - **confirmation-required** — policy confirmation olmadan fail-closed.

### Adım 5 — Revocable kanıtla
- `revokeVSCodeBridge(extensionID:)` çağır (veya VS Code'da `AURA Bridge: Revoke Shared Secret`).
- Sonrası: köprü `.unauthorized`, tüm VS Code yetenekleri `.disabled`, okuma reddedilmeli.

---

## 3. Kanıt kayıtları (EV-SP-012-*)

Canlı kabulü kanıtlayan dosyayı `AURA_RUNTIME_PROMOTION/state/EV-SP-012-<DATE>-LIVE-ACCEPTANCE-<NN>.md`
olarak oluştur. İçinde olmalı:

| Alan | Değer |
|---|---|
| Evidence ID | `EV-SP-012-YYYYMMDD-LIVE-ACCEPTANCE-NN` |
| Prompt | SP-012 / OPEN-07 |
| Class | Direct user-present product/UI/filesystem evidence |
| Commit | `27e9b78` (ya da senin HEAD) |
| Environment | macOS / arm64 / Xcode / Swift |
| Commands | kurulum, secret provisioning, round trip |
| Artifacts | `.vsix` hash, bridge dosyaları, `code --list` çıktısı, health log |
| Result | `.ready`, round-trip sonucu, revoke sonrası reddetme |
| Limitations | hangi yollar canlı koşuldu, hangileri değil |

Sonra aynı `EV-SP-012-*` isimle EVIDENCE_INDEX.md, SECOND_PASS_LEDGER.md, PROGRAM_LEDGER.md,
PROJECT_LEDGER.md, RISK_REGISTER.md, current-state.json, session-handoff.json güncelle
(15_SESSION_CLOSEOUT.prompt.md kuralına uy).

---

## 4. Başarı ölçütü (Completion gate)

SP-012 ancak şunlar **hepsi canlı kanıtlı** olursa `completed` olur:

- [ ] `.vsix` VS Code'da kurulu.
- [ ] AURA ve VS Code aynı shared secret ile eşleştirildi.
- [ ] `vscodeBridgeHealth` → `.ready`.
- [ ] En az bir canlı authenticated command/response/state round-trip koştu.
- [ ] disconnect, version mismatch, replay, stale editor, dirty buffer, confirmation-required path'leri canlı test edildi.
- [ ] Revoke sonrası fail-closed doğrulandı.
- [ ] `EV-SP-012-*-LIVE-*` evidence dosyası ve tüm state/ledger güncellendi.
- [ ] `python3 scripts/validate_second_pass_program.py` PASSED.

Bu koşullardan biri bile eksikse SP-012 **blocked/in_progress** kalır, kanıt eksikliği belgelenir,
SP-013'e geçilmez.

---

## 5. Stop condition

Kullanıcı yoksa, secret giremezsin (secret'i gözden geçirir), install yetkisi sorulamıyorsa veya
VS Code'a bağlanamıyorsan: **SP-012'yi blocked bırak**, tam olarak hangi blocker olduğunu kaydet,
SP-013'e geçme.

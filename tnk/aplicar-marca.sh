#!/usr/bin/env bash
# Aplica a marca TNK Remoto no codigo antes da compilacao (roda no GitHub Actions,
# depois do checkout com submodulos). Edite as variaveis abaixo para mudar nome/servidor/chave.
set -euo pipefail

APP_NAME="${TNK_APP_NAME:-TNK Remoto}"
SERVIDOR="${TNK_SERVIDOR:-tnk-hd.ddns.net}"
CHAVE="${TNK_CHAVE:-35iD3HXNvFurrvhv0fhE9PhZWThe32OqHYIHqne64CY=}"
EMPRESA="${TNK_EMPRESA:-TNK System}"

CFG=libs/hbb_common/src/config.rs

# 1. Nome do app, servidor de ID/relay e chave publica (gravados no binario)
sed -i -E "s|(APP_NAME: RwLock<String> = RwLock::new\()\"RustDesk\"|\1\"${APP_NAME}\"|" "$CFG"
sed -i -E "s|^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[.*\];|pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"${SERVIDOR}\"];|" "$CFG"
sed -i -E "s|^pub const RS_PUB_KEY: &str = \".*\";|pub const RS_PUB_KEY: \&str = \"${CHAVE}\";|" "$CFG"

# 2. Metadados do executavel (Propriedades > Detalhes no Windows)
sed -i -E "s|^ProductName = \".*\"|ProductName = \"${APP_NAME}\"|; s|^FileDescription = \".*\"|FileDescription = \"${APP_NAME}\"|; s|^LegalCopyright = \".*\"|LegalCopyright = \"Baseado no RustDesk (AGPL-3.0). ${EMPRESA}\"|" Cargo.toml
RC=flutter/windows/runner/Runner.rc
sed -i -E "s|(VALUE \"CompanyName\", )\".*\"|\1\"${EMPRESA}\"|; s|(VALUE \"FileDescription\", )\".*\"|\1\"${APP_NAME}\"|; s|(VALUE \"ProductName\", )\".*\"|\1\"${APP_NAME}\"|; s|(VALUE \"LegalCopyright\", )\".*\"|\1\"Baseado no RustDesk (AGPL-3.0). ${EMPRESA}\"|" "$RC"

# 3. Conferencia: falha a compilacao se algo nao foi aplicado
grep -q "RwLock::new(\"${APP_NAME}\"" "$CFG"            || { echo "ERRO: APP_NAME nao aplicado"; exit 1; }
grep -q "RENDEZVOUS_SERVERS: &\[&str\] = &\[\"${SERVIDOR}\"\]" "$CFG" || { echo "ERRO: servidor nao aplicado"; exit 1; }
grep -qF "RS_PUB_KEY: &str = \"${CHAVE}\"" "$CFG"        || { echo "ERRO: chave nao aplicada"; exit 1; }
grep -q "ProductName\", \"${APP_NAME}\"" "$RC"           || { echo "ERRO: Runner.rc nao aplicado"; exit 1; }

echo "Marca aplicada: ${APP_NAME} -> ${SERVIDOR}"
grep -nE "APP_NAME: RwLock|RENDEZVOUS_SERVERS|RS_PUB_KEY" "$CFG"

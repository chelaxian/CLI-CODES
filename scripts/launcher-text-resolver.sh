#!/usr/bin/env bash
# Bash counterpart of launcher-text-resolver.ps1.
# Reads TXT/ first; if TXT/ missing or file empty, leaves variables unset
# so call-sites can fall back to their inline defaults.
#
# Usage:  . "$SCRIPTDIR/launcher-text-resolver.sh"
#         TXT_Providers_DisplayName["zai"]    -> "Z.AI"
#         TXT_Providers_GetKeyUrl["bai"]      -> "https://api.b.ai"
#         TXT_Providers_EnvVar["zai"]         -> "ZAI_API_KEY"
#         TXT_Menu_Installer["9"]             -> "Полное удаление проекта с ПК (uninstall)"
#
# Backward compat: removing TXT/ breaks nothing -- all vars stay unset.

# Resolve SCRIPTDIR and repo root (one level up from scripts/).
# shellcheck disable=SC2154
LAUNCHER_TEXT_RESOLVER_DIR="${BASH_SOURCE%/*}"
if [[ "$LAUNCHER_TEXT_RESOLVER_DIR" == "${BASH_SOURCE}" ]]; then
  LAUNCHER_TEXT_RESOLVER_DIR="."
fi
LAUNCHER_TEXT_ROOT_DIR="$(cd "$LAUNCHER_TEXT_RESOLVER_DIR/.." && pwd)"
LAUNCHER_TXT_ROOT="$LAUNCHER_TEXT_ROOT_DIR/TXT"

# Associative arrays; default empty.
declare -gA TXT_Providers_Key=()
declare -gA TXT_Providers_DisplayName=()
declare -gA TXT_Providers_GetKeyUrl=()
declare -gA TXT_Providers_EnvVar=()
declare -gA TXT_Menu_Installer=()
declare -gA TXT_Menu_Subtitles=()
declare -gA TXT_Menu_ClaudeTop=()

# Returns 0 if file has at least one non-comment, non-blank line.
__launcher_txt_has_content() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    return 0
  done < "$file"
  return 1
}

# Parse pipe-delimited rows from $1, dispatch each line to handler $2.
__launcher_txt_parse_pipes() {
  local file="$1"; shift
  local handler="$1"; shift
  [[ -f "$file" ]] || return 0
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    local line="${raw%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    "$handler" "$line" "$@"
  done < "$file"
}

__txt_on_provider_line() {
  local line="$1"
  IFS='|' read -r key display url env _rest <<< "$line"
  [[ -z "$key" ]] && return 0
  TXT_Providers_Key["$key"]="$key"
  TXT_Providers_DisplayName["$key"]="$display"
  TXT_Providers_GetKeyUrl["$key"]="$url"
  TXT_Providers_EnvVar["$key"]="$env"
}

__txt_on_menu_installer_line() {
  local line="$1"
  IFS='|' read -r key val _rest <<< "$line"
  [[ -z "$key" ]] && return 0
  TXT_Menu_Installer["$key"]="$val"
}

__txt_on_menu_subtitles_line() {
  local line="$1"
  IFS='|' read -r key val _rest <<< "$line"
  [[ -z "$key" ]] && return 0
  TXT_Menu_Subtitles["$key"]="$val"
}

__txt_on_menu_claudetop_line() {
  local line="$1"
  IFS='|' read -r key val _rest <<< "$line"
  [[ -z "$key" ]] && return 0
  TXT_Menu_ClaudeTop["$key"]="$val"
}

if [[ -d "$LAUNCHER_TXT_ROOT" ]]; then
  __launcher_txt_has_content "$LAUNCHER_TXT_ROOT/providers.txt" && \
    __launcher_txt_parse_pipes "$LAUNCHER_TXT_ROOT/providers.txt" __txt_on_provider_line

  __launcher_txt_has_content "$LAUNCHER_TXT_ROOT/menus/installer.txt" && \
    __launcher_txt_parse_pipes "$LAUNCHER_TXT_ROOT/menus/installer.txt" __txt_on_menu_installer_line

  __launcher_txt_has_content "$LAUNCHER_TXT_ROOT/menus/subtitles.txt" && \
    __launcher_txt_parse_pipes "$LAUNCHER_TXT_ROOT/menus/subtitles.txt" __txt_on_menu_subtitles_line

  __launcher_txt_has_content "$LAUNCHER_TXT_ROOT/menus/claude-top.txt" && \
    __launcher_txt_parse_pipes "$LAUNCHER_TXT_ROOT/menus/claude-top.txt" __txt_on_menu_claudetop_line
fi

# Public helper: print a provider field with fallback.
# Usage:  launcher_txt_provider "zai" "DisplayName"
launcher_txt_provider() {
  local prov="$1"; local field="$2"
  case "$field" in
    Key)         echo "${TXT_Providers_Key[$prov]:-$prov}";;
    DisplayName) echo "${TXT_Providers_DisplayName[$prov]:-$prov}";;
    GetKeyUrl)
      case "$prov" in
        zai)        echo "${TXT_Providers_GetKeyUrl[$prov]:-https://z.ai/manage-apikey/apikey-create}";;
        nim)        echo "${TXT_Providers_GetKeyUrl[$prov]:-https://build.nvidia.com/settings/secrets}";;
        bai)        echo "${TXT_Providers_GetKeyUrl[$prov]:-https://api.b.ai}";;
        openrouter) echo "${TXT_Providers_GetKeyUrl[$prov]:-https://openrouter.ai/keys}";;
        *)          echo "${TXT_Providers_GetKeyUrl[$prov]:-}";;
      esac
      ;;
    EnvVar)
      case "$prov" in
        zai)        echo "${TXT_Providers_EnvVar[$prov]:-ZAI_API_KEY}";;
        nim)        echo "${TXT_Providers_EnvVar[$prov]:-NVIDIA_NIM_API_KEY}";;
        bai)        echo "${TXT_Providers_EnvVar[$prov]:-BAI_API_KEY}";;
        openrouter) echo "${TXT_Providers_EnvVar[$prov]:-OPENROUTER_API_KEY}";;
        *)          echo "${TXT_Providers_EnvVar[$prov]:-}";;
      esac
      ;;
  esac
}

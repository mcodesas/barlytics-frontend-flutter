#!/usr/bin/env bash
# Flutter 3.41.9 + flutter_secure_storage_linux 1.2.3 integran una versión
# de nlohmann/json.hpp con literales _json y _json_pointer obsoletos.
# Clang reciente promueve esta advertencia a error por -Werror.
# Conservamos las demás advertencias como errores de compilación:
# solo esta advertencia del plugin de terceros queda exenta.
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-Wno-error=deprecated-literal-operator"

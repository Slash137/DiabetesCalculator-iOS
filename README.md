# DiabetesCalculator iOS

Version iPhone de `DiabetesCalculator` con UI nativa de iOS (SwiftUI), manteniendo el flujo principal de Android:

- Nueva comida con multiples alimentos, plantillas, notas y calculo en tiempo real.
- Historial con filtros por periodo, busqueda y estado de dosis.
- Biblioteca de alimentos con alta/edicion/borrado.
- Perfil con parametros de calculo, objetivos diarios y Nightscout.
- Recordatorio local de glucosa a las 2h.
- Backup/export/import JSON y export CSV.
- Seed inicial de alimentos desde `alimentos_librito.csv`.

## Requisitos

- Xcode 26.2+
- Runtime de iOS Simulator instalado

## Generar proyecto

```bash
cd /Users/cayetano/.gemini/antigravity/scratch/DiabetesCalculatoriOS
xcodegen generate
```

## Compilar en simulador

```bash
xcodebuild \
  -project DiabetesCalculatoriOS.xcodeproj \
  -scheme DiabetesCalculatoriOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build
```

## Ejecutar en simulador (sin iPhone fisico)

```bash
xcrun simctl boot 'iPhone 17 Pro'
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/DiabetesCalculatoriOS.app' | head -n 1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.diabetes.calculator.ios
```

## Compilar e instalar en iPhone real

1. Abre el proyecto:

```bash
open DiabetesCalculatoriOS.xcodeproj
```

2. Conecta el iPhone por cable (o misma Wi-Fi), desbloquealo y acepta `Confiar en este Mac`.
3. Activa `Modo desarrollador` en el iPhone:
`Ajustes > Privacidad y seguridad > Modo desarrollador` (reinicia si lo solicita).
4. En Xcode, inicia sesion con tu Apple ID:
`Xcode > Settings > Accounts`.
5. En target `DiabetesCalculatoriOS`, entra a `Signing & Capabilities` y configura:
- `Automatically manage signing` en `ON`.
- `Team` con tu Apple ID.
- `Bundle Identifier` unico (por ejemplo `com.tunombre.diabetescalculator.ios`).
6. Selecciona tu iPhone como destino de ejecucion en Xcode y pulsa `Run` (`▶`).
7. Si iOS bloquea la primera apertura:
`Ajustes > General > VPN y gestion de dispositivos > Developer App > Trust`.

Notas:
- El proyecto esta configurado para iOS 17 o superior.
- Con cuenta gratuita de Apple, la firma de desarrollo suele caducar cada ~7 dias.

## Nota

Esta app es una ayuda y no sustituye criterio medico profesional.

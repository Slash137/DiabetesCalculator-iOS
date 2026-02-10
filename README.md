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

## Nota

Esta app es una ayuda y no sustituye criterio medico profesional.

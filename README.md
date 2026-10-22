# JGR_Dealership

Concesionario de vehículos para FiveM con catálogo en NUI, previsualización con cámara, prueba de manejo en dimensión aislada y panel de staff para gestionar el catálogo desde el juego.

`versión 1.1.0` · `QBCore · Qbox · ESX Legacy · Standalone / ox_core` · `oxmysql`

---

## Características

- **Catálogo en NUI** por categorías, con buscador, orden (precio / nombre), favoritos (guardados en el navegador del jugador), estadísticas orientativas y una estimación de financiación a 48 meses (solo informativa).
- **Previsualización** del vehículo en el concesionario con cámara, rotación, cambio de color (paleta o RGB) y luces.
- **Compra** con **banco** o **efectivo**. El precio y el modelo se leen siempre de la base de datos (el cliente no puede cambiarlos). El vehículo aparece en `BuySpawn` con el jugador dentro y se guarda en la tabla de vehículos del framework.
- **Garaje “de casa” automático** (QBCore/Qbox): se guarda en `player_vehicles.garage` el garaje que más usa el jugador, un export configurable o `Config.DefaultGarage`.
- **Prueba de manejo** con duración configurable en un **routing bucket** aleatorio (no te cruzas con nadie). Se cancela con **G**, al bajarte del coche o al acabar el tiempo, y vuelves al concesionario.
- **Panel de staff** (`/staffconcesionario`): añadir, editar y eliminar vehículos del catálogo; se actualiza en vivo para quien tenga el concesionario abierto.
- **Varios concesionarios** (`Config.Dealerships`) con su vendedor (ped), blip, punto de previsualización y de entrega.
- Interacción con **tecla E** o con **ox_target / qb-target**.
- Tabla `jgr_dealership_vehicles` creada automáticamente con vehículos de ejemplo.
- Textos de la interfaz en **español** o **inglés** (`Config.UI.Locale`).

## Requisitos

| Recurso | ¿Obligatorio? | Notas |
|---|---|---|
| [oxmysql](https://github.com/overextended/oxmysql) | **Sí** | Base de datos |
| Framework: `qbx_core`, `qb-core`, `es_extended` u `ox_core` | Recomendado | Se detecta solo. Sin framework funciona en modo standalone (ver compatibilidad) |
| `ox_target` o `qb-target` | Opcional | Con `Config.UseTarget = true` |
| `ox_lib` | Opcional | Notificaciones en standalone / ox_core |
| `ox_inventory` | Opcional | Dinero en efectivo en standalone / ox_core (item `money`) |
| Script de llaves | Opcional | Ver `Config.GiveVehicleKeys` |

## Instalación

1. Copia la carpeta con el nombre exacto **`JGR_Dealership`** (si la renombras, el recurso se detiene al arrancar).
2. **Base de datos**: la tabla `jgr_dealership_vehicles` se crea sola al iniciar y se rellena con 6 vehículos de ejemplo si está vacía. `sql/jgr_dealership.sql` es solo de referencia.
   Los vehículos comprados se guardan en la tabla de tu framework (ver [Compatibilidad](#compatibilidad-con-frameworks)); no hace falta crear nada más.
3. **server.cfg** (el framework siempre antes):

   ```cfg
   ensure oxmysql
   ensure qb-core          # o qbx_core / es_extended / ox_core
   ensure ox_target        # opcional
   ensure JGR_Dealership
   ```

4. Da permiso de staff si no usas los grupos de admin del framework:

   ```cfg
   add_ace group.admin jgr_dealership.admin allow
   ```

5. Ajusta `config.lua` (coordenadas, garaje por defecto, llaves) y reinicia.

## Configuración

| Opción | Por defecto | Descripción |
|---|---|---|
| `Config.Framework` | `'auto'` | `'auto'`, `'qbx'`, `'qb'`, `'esx'`, `'ox'` o `'standalone'`. `auto` detecta: qbx_core → qb-core → es_extended → ox_core → standalone |
| `Config.DefaultGarage` | `'pillboxgarage'` | Garaje si no se detecta otro (solo QBCore/Qbox) |
| `Config.VehicleOutState` | `0` | Estado con el que se guarda el coche comprado (`state` en QB/Qbox, `stored` en ESX; 0 = fuera) |
| `Config.GarageResolver` | — | `sqlFallback` (usar el garaje que más repite el jugador), `ignoreGarageNames`, `tryExports` (`{ resource, export, type = 'source' \| 'citizenid' }`) |
| `Config.ESX.vehicleType` | `'car'` | Valor de `owned_vehicles.type` en ESX |
| `Config.GiveVehicleKeys` | qb-vehiclekeys | Función de cliente `(vehicle, plate, framework)` para dar llaves; adáptala a tu sistema |
| `Config.UseTarget` | `false` | Usar ox_target / qb-target en el vendedor (si no hay target, tecla E) |
| `Config.DealerPed` | — | Modelo del vendedor y blip |
| `Config.TestDrive` | — | `enabled`, `duration` (s), rango de buckets, `spawn` y `returnCoords` |
| `Config.Dealerships` | `Main` | Por concesionario: `coords`, `PreviewSpawn`, `PreviewCam`, `BuySpawn` |
| `Config.Brand` | — | Título, subtítulo y lema de la interfaz |
| `Config.UI` | — | `CurrencySymbol` y `Locale` (`'es'` / `'en'`) |

## Compatibilidad con frameworks

| Función | QBCore | Qbox | ESX Legacy | Standalone / ox_core |
|---|---|---|---|---|
| Catálogo, previsualización, prueba de manejo, panel de staff | Sí | Sí | Sí | Sí |
| Pago en efectivo | `cash` | `cash` | `getMoney` / `removeMoney` | Item `money` de ox_inventory |
| Pago por banco | `bank` | `bank` | cuenta `bank` | No (se cobra en efectivo) |
| **Tabla donde se guarda el coche** | `player_vehicles` | `player_vehicles` | `owned_vehicles` | **No se guarda** (se entrega el coche y se avisa en consola) |
| Columnas usadas | `license, citizenid, vehicle, hash, mods, plate, garage, state` | igual que QBCore | `owner, plate, vehicle (JSON {model, plate}), type, stored` | — |
| Garaje “de casa” | Sí | Sí | No (owned_vehicles no tiene garaje estándar) | No |
| Llaves (por defecto) | `vehiclekeys:client:SetOwner` | `vehiclekeys:client:SetOwner` | Configura `Config.GiveVehicleKeys` | Configura `Config.GiveVehicleKeys` |
| Staff | admin/god de QBCore o ACE | `group.admin` o ACE | grupo `admin`/`superadmin` o ACE | ACE `jgr_dealership.admin` |
| Notificaciones | QBCore | qbx_core | ESX | ox_lib o nativa |

> En ESX la columna `owner` recibe `xPlayer.identifier` (equivale al `citizenid` de QBCore).
> En ox_core se usa el camino standalone (sin guardar el vehículo): si quieres persistencia, conecta tu sistema de vehículos en `Bridge.SaveOwnedVehicle` (`bridge/server.lua`).

## Comandos

| Comando | Permiso | Descripción |
|---|---|---|
| `/staffconcesionario` | Admin (ver tabla) o ACE `jgr_dealership.admin` | Abre el panel de staff del catálogo |

**En el juego:** **E** junto al vendedor (o target) abre el concesionario · **G** cancela la prueba de manejo.

## Eventos

- `jgr_dealership:client:RefreshVehicles` (servidor → todos): se dispara al cambiar el catálogo.
- `jgr_dealership:client:VehicleBought (model, plate)` (servidor → cliente): entrega del coche comprado.
- Los eventos de servidor (`BuyVehicle`, `AddVehicle`, `EditVehicle`, `DeleteVehicle`, `TestDriveExit`) validan todo en el servidor; no están pensados para llamarse desde otros recursos.

## Actualizaciones

Al arrancar, el recurso comprueba en consola si hay una versión nueva (usa `version` y `jgr_version_key` del `fxmanifest.lua` y el `versions.json` central de JGR). Para desactivar el aviso, en `server.cfg`:

```cfg
set jgr_versioncheck 0
```

## Changelog

### v1.1.0
- **Multi-framework**: QBCore, Qbox, ESX Legacy y standalone/ox_core con detección automática (`Config.Framework`). Nuevo `bridge/` (shared, client, server); el resto del código ya no llama a qb-core.
- Eliminada la dependencia de `@qb-core/shared/locale.lua` (no se usaba).
- Vehículos comprados: `player_vehicles` (QBCore/Qbox) u `owned_vehicles` (ESX).
- Callbacks propios cliente↔servidor (antes `QBCore.Functions.CreateCallback`).
- `Config.GiveVehicleKeys` para cualquier script de llaves, `Config.ESX.vehicleType` y soporte de **ox_target** además de qb-target.
- Comprobador de versiones común (`server/version_check.lua`); se quita el antiguo de `server/init.lua`.
- Correcciones de seguridad:
  - **La compra usaba el precio y el modelo que mandaba el cliente**: se podía comprar cualquier coche por 1 $. Ahora se leen de `jgr_dealership_vehicles` y hay que estar en el concesionario.
  - `TestDriveExit` permitía a cualquier cliente moverse al routing bucket 0 (salir de otras dimensiones). Ahora solo restaura si estaba en una prueba.
  - Inicio de prueba de manejo solo cerca de un concesionario; anti doble compra simultánea.
- Otras correcciones:
  - Si fallaba el guardado del coche, el dinero se perdía: ahora se devuelve.
  - `QBCore.Functions.LoadModel` se quedaba esperando para siempre con un modelo inexistente del catálogo (pantalla bloqueada): ahora hay validación y timeout.
  - Los exports de `Config.GarageResolver.tryExports` se llamaban sin `self`, por lo que no recibían el argumento.
  - `GeneratePlate` recursivo sin límite → bucle con 50 intentos.
  - `OpenDealership`/`CloseDealership` eran globales accidentales.
  - El SQL se enviaba a los clientes (`files`) y el auto-import ignoraba el `INSERT` por el comentario previo: simplificado.
  - El bucle de interacción iba a `Wait(0)` en 15 m; ahora solo a menos de 3 m (250 ms en el resto) y nada si se usa target.
  - Cada cambio del catálogo hacía que todos los jugadores pidiesen el catálogo al servidor; ahora solo quien tiene la interfaz abierta.
  - Validación de longitud y precio en el panel de staff.

### v1.0.0
- Versión inicial (solo QBCore).

## Soporte y créditos

Desarrollado por **JGR** · GitHub: [jgr-ry](https://github.com/jgr-ry) · Repositorio: [jgr-ry/JGR_Dealership](https://github.com/jgr-ry/JGR_Dealership)

Para dudas o errores, abre un issue en el repositorio.

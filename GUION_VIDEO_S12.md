# Guion del video — Taller Semana 12

**Autenticación, navegación, estado y formularios**
Aplicaciones Móviles · 2626-UEA-L-UFPTI-008-C · Modalidad individual
Duración objetivo: **4 minutos** (el rango permitido es 3 a 5)

> El taller pide demostrar la aplicación **funcionando**, no capturas. Todo lo que sigue se ejecuta en vivo sobre el teléfono físico.

---

## Antes de grabar (lista de comprobación)

- [ ] **Backend levantado.** En `atlas-backend`: `docker compose up -d`. Comprueba `http://localhost:8000/health`.
- [ ] **Datos cargados.** Si la base está vacía: `docker compose exec api python seed.py`.
- [ ] **Firewall abierto.** PowerShell como administrador: `powershell -ExecutionPolicy Bypass -File .\herramientas\abrir-firewall.ps1`.
- [ ] **Teléfono conectado** por USB, depuración activada, misma red Wi-Fi. Verifica con `adb devices`.
- [ ] **Pruebas en verde.** Ejecuta `flutter test` una vez antes de grabar: las 17 deben pasar.
- [ ] **Sesión anterior cerrada.** La sesión ahora se guarda cifrada y sobrevive al cierre de la aplicación. Si quedaste dentro de una grabación anterior, **cierra sesión desde Perfil** antes de empezar; si no, el video arrancará en el área privada en vez de en el login.
- [ ] **Cuenta de demostración lista.** Vas a lanzar con las credenciales inyectadas:
      `.\run.ps1 -DemoEmail demo@atlas.app -DemoPassword <la-del-seed>`
- [ ] **Correo de registro nuevo.** Decide de antemano el correo que vas a usar al registrarte (por ejemplo `andy.demo@atlas.app`); si ya existe, el backend devuelve 409 y perderás el momento del alta correcta.
- [ ] **Aplicación cerrada del todo** antes de empezar, para que el video arranque en el login.
- [ ] **Pantalla del teléfono visible.** Cámara apuntando al teléfono o `scrcpy` proyectando.

---

## Bloque 0 — Presentación (20 s)

> "Soy Andy Toala. Este es el taller de la Semana 12 de Aplicaciones Móviles, sobre mi proyecto integrador **Atlas**: una aplicación que captura ideas, las convierte en publicaciones con inteligencia artificial y mide cómo rinden.
>
> La semana pasada dejé el entorno montado y la aplicación hablando con mi propio backend. Hoy le agrego el flujo de sesión completo: autenticación, registro, navegación protegida, manejo de estado y formularios validados."

---

## Bloque 1 — Ejecución de la aplicación (20 s)

**Ejecuta:**

```powershell
.\run.ps1 -DemoEmail demo@atlas.app -DemoPassword <la-del-seed>
```

> "Arranco con el lanzador del proyecto. Detecta la IP del computador, sincroniza la política de seguridad de red de Android y compila sobre el teléfono físico. La URL de la API y las credenciales de demostración se inyectan como variables de entorno: **no están escritas en el repositorio**."

**En pantalla:** el teléfono muestra un instante la pantalla de arranque y cae en el **formulario de inicio de sesión**.

> "Fíjense en el primer detalle: la aplicación no arranca en el contenido. Arranca comprobando si hay una sesión guardada en el almacén cifrado del teléfono; como no la hay, va al login."

---

## Bloque 2 — Validaciones del formulario (45 s)

Haz esto **en orden**, sin prisa, para que se lean los mensajes.

**2.1 Campos vacíos.** Pulsa *Iniciar sesión* con todo en blanco.

> "Campos obligatorios: 'El correo es obligatorio', 'La contraseña es obligatoria'. Y algo importante: **no salió ninguna petición de red**. El formulario no se valida contra el servidor, se valida antes."

**2.2 Formato inválido.** Escribe `correo-sin-arroba` y la contraseña `123`.

> "Ahora el formato: el correo no cumple el patrón y la contraseña se queda corta. Los límites que aplico aquí son los mismos que declara el esquema de Pydantic en mi backend: contraseña de 6 a 72 caracteres. Así el teléfono rechaza exactamente lo que rechazaría el servidor."

**2.3 Corrección en vivo.** Empieza a escribir un correo válido.

> "Y en cuanto corrijo, el error desaparece solo. Hasta el primer envío no marco nada en rojo; después, cada pulsación revalida."

---

## Bloque 3 — Credenciales incorrectas (25 s)

Escribe `demo@atlas.app` con una contraseña equivocada. Pulsa *Iniciar sesión*.

> "Ahora los datos son válidos como formato, así que la petición **sí** sale. El backend responde 401 y la aplicación no muestra el error crudo: lo traduce a 'Correo o contraseña incorrectos'.
>
> El cliente HTTP conserva el código de estado y la capa de estado decide el mensaje: 401 es credenciales, 409 es correo ya registrado, 422 son los errores de validación del servidor. Y seguimos en el login: no se abrió nada."

---

## Bloque 4 — Registro de usuario (40 s)

Pulsa *Crear una cuenta*.

> "Mi backend expone `POST /auth/register`, así que la aplicación ofrece autorregistro."

**4.1 Contraseñas que no coinciden.** Llena el formulario y escribe una confirmación distinta.

> "Aquí hay una validación que solo existe en el cliente: la confirmación de la contraseña. El servidor no la conoce."

**4.2 Contraseña sin número.** Escribe `solotexto`.

> "Y esta regla es más estricta que la del backend a propósito: al crear la cuenta exijo al menos una letra y un número."

**4.3 Alta correcta.** Corrige, elige el tono de redacción y pulsa *Registrarme*.

> "El registro crea el usuario, su perfil de tono, y devuelve el token. Entro directo, sin pasar otra vez por el login."

---

## Bloque 5 — Autenticación y pantalla protegida (50 s)

Cierra sesión desde *Perfil* si quedaste dentro, y vuelve al login. Pulsa *Usar cuenta de demostración* y entra.

> "Ahora con la cuenta que trae datos. La aplicación hace dos llamadas: `POST /auth/login` para obtener el JWT, y `GET /auth/me` para el perfil.
>
> Ese `me` no consulta la base de datos: la identidad viaja firmada dentro del token, en los claims. Es la optimización que implementé en la semana 8 y que aquí se aprovecha.
>
> Y ya estoy en el área privada, que es la primera pantalla protegida: mis ideas, traídas con `GET /ideas` y el token en la cabecera `Authorization`."

Pulsa el **icono del velocímetro**, arriba a la derecha del listado. Se despliega el panel técnico.

> "Aquí abro el detalle técnico de la última respuesta. Estas son las cabeceras reales que devuelve mi backend: el tiempo de proceso en el servidor y el número de consultas SQL. La información viene de la API, no está quemada en el cliente."

Con el panel abierto, **cambia el interruptor "Consulta optimizada"** y observa cómo salta el número de consultas SQL.

> "Y este interruptor alterna el parámetro `optimized` de `GET /ideas`. Con eager loading el número de consultas es constante; sin él aparece el problema N+1, una consulta extra por cada idea. Con las ideas que tengo cargadas, la diferencia se ve de golpe."

Vuelve a pulsar el velocímetro para cerrar el panel.

---

## Bloque 6 — Navegación y permanencia del estado (50 s)

**Este bloque es el que más puntúa. No lo apures.**

**6.1 Tres pantallas.** Recorre *Ideas* → *Panel* → *Perfil* con la barra inferior.

> "Navego entre las tres secciones. Miren la barra superior: **mi nombre sigue ahí en las tres**. No lo guarda ninguna pantalla; lo lee del controlador de sesión, que es común a todas."

**6.2 Cuarta pantalla, con `push`.** Vuelve a *Ideas* y abre una idea.

> "El detalle se abre con `pushNamed` y recibe la idea como argumento. Aquí también aparece el usuario: el estado alcanza igual a las rutas apiladas, no solo a las pestañas."

Vuelve atrás.

> "Y al volver, la lista ya está: **no se repitió la petición**. Las ideas viven en su controlador, no en el widget."

**6.3 El borrador.** Pulsa *Nueva idea*, escribe un título a medias, sal sin guardar.

> "Escribo una idea a medias… y me salgo."

Muestra el aviso *"Tienes un borrador sin guardar"* y vuelve a entrar.

> "El texto sigue intacto. La pantalla se destruyó, el estado no."

**6.4 Explicación técnica** (dilo mientras muestras el árbol de carpetas en VS Code):

> "El manejo de estado lo resolví con las herramientas del propio Flutter, sin paquetes externos: `ChangeNotifier` para guardar y notificar, un `InheritedWidget` llamado `AmbitoAtlas` para repartirlo, y `ListenableBuilder` para redibujar solo lo que depende del dato.
>
> Lo decisivo es **dónde** viven los tres controladores: por encima del `Navigator`. Por eso sobreviven a la navegación.
>
> La navegación es por rutas con nombre, todas en un solo archivo, `rutas/rutas.dart`, con un único `onGenerateRoute`."

---

## Bloque 6.5 — La sesión sobrevive al cierre (20 s) *[opcional si vas justo]*

Cierra la aplicación por completo (deslízala fuera de las recientes) y vuelve a abrirla desde el icono.

> "Y esto va un paso más allá de lo que pide el taller. Cierro la aplicación del todo… y al volver a abrirla entro directo, sin volver a escribir la contraseña.
>
> El token JWT se guarda en el almacén cifrado del sistema: `EncryptedSharedPreferences` respaldado por el Keystore de Android, o el Keychain en iOS. **Nunca en almacenamiento en claro.** Al arrancar se lee, se valida contra `GET /auth/me`, y si el backend lo rechaza se borra y aparece el login. En el perfil se ve el origen de la sesión: 'restaurada del almacén cifrado'."

---

## Bloque 7 — Cierre de sesión y bloqueo posterior (40 s)

**7.1 Cerrar sesión.** *Perfil* → **baja hasta el final de la pantalla** → *Cerrar sesión* → confirmar en el diálogo.

> "Cierro sesión. Se borra el token del cliente HTTP **y del almacén cifrado**, y se limpian los datos cargados, para que las ideas de un usuario no queden visibles para el siguiente que entre en este mismo teléfono."

**7.2 Intento de acceso.** En el login, pulsa *Probar acceso directo*.

> "Y esta es la prueba de la protección. Este enlace intenta abrir el área privada a propósito.
>
> No entra: aparece 'Esta sección es privada'. Cada ruta protegida se construye envuelta en una guardia que escucha al controlador de sesión. Como la guardia está en la tabla de rutas y no dentro de cada pantalla, no hay forma de esquivarla: da igual de dónde venga la navegación.
>
> Y la protección es doble: aunque alguien llegara a la pantalla, la API respondería 401, porque la cabecera de autorización iría vacía."

---

## Bloque 8 — Organización del código y cierre (30 s)

**En pantalla:** el árbol de `lib/` en VS Code.

> "Cierro con la organización, que el taller pide de forma expresa.
>
> `modelos` son los datos. `servicios` tiene el cliente HTTP —la única puerta a la API— y el almacén cifrado del token. `estado` son los tres controladores. `rutas` es la tabla de navegación con su guardia. `pantallas` son las páginas. `widgets` son los componentes que se repiten. `utiles/validadores.dart` concentra las reglas de los formularios. Y `tema/tema_atlas.dart` es el sistema de diseño: la paleta, la tipografía y el estilo de cada componente en un solo archivo, con tema claro y oscuro.
>
> Esa separación no es mía por gusto: es la misma que sigue el proyecto de referencia de la asignatura —una puerta HTTP única, el token en almacenamiento seguro y nunca en claro, el estado en su propia capa, y las rutas protegidas separadas de las páginas—, traducida de Ionic a Flutter.
>
> Todo el flujo está cubierto por diecisiete pruebas automatizadas contra un backend simulado, que corren con `flutter test` sin necesidad de levantar la API.
>
> El repositorio y el detalle técnico de estas decisiones están en la sección 7 del README. Gracias."

*(Si sobra tiempo, muestra la salida verde de `flutter test`. Si va justo, sáltalo: ya está dicho.)*

---

## Después de grabar

- [ ] Subir el video a YouTube (**no listado**) o a Drive.
- [ ] **Verificar permisos**: abre el enlace en incógnito y confirma que se ve sin iniciar sesión.
- [ ] Confirmar que el repositorio `atlas-app` es accesible para el docente.
- [ ] Comprobar que lo mostrado en el video **coincide con el código publicado** (haz el push antes de entregar).
- [ ] Subir a Moodle el enlace del video **y** el del repositorio.

---

## Cobertura de la rúbrica

| Criterio | Puntaje | Bloques |
|---|---|---|
| 1. Autenticación y protección de vistas | 3,0 | 3, 4, 5 y 7 |
| 2. Formularios y validaciones | 3,0 | 2 y 4 |
| 3. Navegación y manejo de estado | 2,0 | 6 |
| 4. Organización del código y evidencia | 2,0 | 8 (y el README, §7) |
| **Total** | **10** | |

## Lo que el taller exige, y dónde se ve

| Requisito | Bloque |
|---|---|
| Ejecución de la aplicación | 1 |
| Formulario de inicio de sesión | 1 y 2 |
| Validaciones del formulario | 2 |
| Autenticación correcta | 5 |
| Comportamiento ante datos incorrectos | 2 y 3 |
| Ingreso a una funcionalidad protegida | 5 |
| Navegación entre al menos tres pantallas | 6.1 y 6.2 |
| Mantenimiento del estado durante la navegación | 6.1, 6.2 y 6.3 |
| Cierre de sesión | 7.1 |
| Intento de acceso tras cerrar sesión | 7.2 |
| Explicación del estado y la navegación | 6.4 |
| Registro de usuario | 4 |

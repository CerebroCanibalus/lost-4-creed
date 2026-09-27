# Security Policy

## 🔒 Reportar una vulnerabilidad

**No abras un issue público para reportar un fallo de seguridad.**

Este modpack se ejecuta dentro del proceso del juego. Un fallo de seguridad aquí
significa, típicamente, ejecución de código no deseado o crash del cliente — y en
algunos casos, cosas que afectan a la partida de otras personas en un servidor
cooperativo.

Reporta por GitHub con la opción **"Report a vulnerability"** ( pestaña
`Security` → `Advisories` → `Report a vulnerability`), que abre un reporte privado
entre tú y los mantenedores. Si no la ves, abre un issue privado con la etiqueta
`security` y marca claramente que no debe hacerse público.

Incluye:

- Descripción del fallo y pasos para reproducirlo
- Versión del modpack y commit
- Mapa y modo
- Impacto: ¿afecta solo a quien lo reproduce o también a otros jugadores?
- Salida de consola con el error

Nos comprometemos a responder en un plazo razonable y a darte crédito en el aviso
si lo deseas.

---

## 🛡️ Alcance

**En alcance:**

- VScript del modpack (`*.nut` / `*.nuc`)
- `Compile-VPKs.ps1` y scripts de build
- `testing/test_vscripts.ps1`
- Configuración de addons

**Fuera de alcance:**

- **El motor de Left 4 Dead 2 y el binario del juego.** Es software propietario de
  Valve. Los bugs del motor se reportan a Valve.
- **Los assets** (modelos, texturas, sonidos). No están en este repositorio.
- **Vulnerabilidades en el intérprete VScript o Squirrel de L4D2.** Esas son de
  Valve, no de este proyecto.

---

## ⚠️ Nota importante sobre naturaleza

Lost 4 Creed es un mod para un juego cooperativo multijugador. Todo lo que hace
ocurre en tu propia máquina y en la partida en la que participas, y el código se
carga desde VPK locales — no se descarga ni se ejecuta de forma remota.

Aun así, tractamos los reports en serio: un fallo de carga de rutas o un
`RunScriptCode` mal construido puede producir ejecución de código no previsto. Si
encuentras algo así, dilo.

---

## 🛡 Buenas prácticas para quien reporta

- No explotes vulnerabilidades en servidores de terceros o con jugadores que no
  hayan consentido.
- Da tiempo para publicar un arreglo antes de divulgar detalles técnicos.
- Preferimos disclosure coordinado sobre responsible disclosure.

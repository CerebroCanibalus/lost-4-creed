## Qué cambia

<!-- Una sola cosa por PR. -->

## Por qué

<!-- El qué se ve en el diff. El porqué no. -->

Closes #

## Checklist

- [ ] He leído [`AGENTS.md`](../../blob/main/AGENTS.md) y mi cambio no viola el load order
- [ ] He actualizado `l4cCoreAddon/CHANGELOG.md` con fecha
- [ ] He ejecutado `.\testing\test_vscripts.ps1 -Full -Verbose` — pego abajo el resultado
- [ ] Si toca carga, eventos o timers, cito la sección de `AGENTS.md` que lo governs
- [ ] No subo assets, VPK, ni nada de `referencias/`, `references/` o `tools/`
- [ ] He comprobado `git status` antes de commitear

## Salida del validador

```
<pegar aquí>
```

## Afecta a MaoLib

- [ ] No
- [ ] Sí — es aditivo, no rompe nada existente
- [ ] Sí — **cambia API existente** (explica abajo la migración)

## Afecta a load order o eventos

- [ ] No
- [ ] Sí — explico abajo por qué es seguro

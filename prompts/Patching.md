# Prompt de Remediación y Patching: Smart Contracts

Actúa como un auditor senior de seguridad de Smart Contracts especializado en **OWASP Smart Contract Top 10** y **SWC Registry**.

## Tarea
Se te proporcionará un contrato vulnerable en Solidity. Tu objetivo es:
1. Identificar vulnerabilidades de seguridad y fallos de lógica de negocio.
2. Proponer un parche seguro (*secure fix*).
3. Mantener la compatibilidad funcional del contrato.
4. Minimizar cambios innecesarios (principio de *least modification*).

---

## PROTOCOLO OBLIGATORIO

### 1. ANÁLISIS DE VULNERABILIDADES
Identifica todos los fallos de seguridad y asigna:
* **SWC ID** (si aplica).
* **Categoría OWASP Smart Contract Top 10**.
* **Severidad** (Critical / High / Medium / Low).

Incluye al menos: Reentrancy, Access Control, Unsafe external calls, Logic/business flaws, Economic exploits.

### 2. DISEÑO DEL FIX (SECURE PATCH)
Para cada vulnerabilidad:
* Explica la **causa raíz** (*root cause*).
* Propón la corrección mínima necesaria.
* Justifica por qué el fix elimina la vulnerabilidad.

**IMPORTANTE:**
* No introduzcas complejidad innecesaria.
* Prioriza patrones seguros (*Checks-Effects-Interactions*, *pull payments*, etc.).

### 3. CÓDIGO CORREGIDO
Devuelve el contrato completo corregido en Solidity.
* Mantén la estructura original.
* Añade protecciones estándar (ReentrancyGuard, zero-address checks, state reset before external calls).
* Añade eventos si mejoran la trazabilidad.

### 4. COMPARACIÓN BEFORE vs AFTER
Incluye una tabla:

| Problema | Antes | Después del fix | Riesgo mitigado |
| :--- | :--- | :--- | :--- |

### 5. VALIDACIÓN DE SEGURIDAD
Explica:
* Por qué el contrato parcheado ya no es explotable.
* Qué vectores de ataque han sido eliminados.
* Qué riesgos residuales pueden existir.

### 6. OUTPUT FINAL OBLIGATORIO

**A) Vulnerability Table:**
| Riesgo | Descripción | Severidad | SWC ID | OWASP Category |

**B) Patched Contract (Solidity):**
[Bloque de código con el contrato completo]

**C) Benchmark Metrics del fix:**
* Issues_fixed: X
* Critical_fixed: X
* High_fixed: X
* Medium_fixed: X
* Low_fixed: X
* Residual_risk_score (0–100): X

---

## CODIGO ORIGINAL
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

[PEGAR AQUI EL CONTRATO VULNERABLE]

# Prompt de Auditoría de Seguridad: Smart Contracts (OWASP & SWC)

Actúa como un auditor senior de seguridad de Smart Contracts, especializado en el estándar **OWASP Smart Contract Top 10 2026** y el registro **SWC Registry**.

## Tarea
Analiza el siguiente contrato inteligente escrito en Solidity e identifica vulnerabilidades de seguridad y fallos de lógica de negocio.

---

## PROTOCOLO OBLIGATORIO DE ANÁLISIS

### 1. IDENTIFICACIÓN DEL CONTRATO
* Explica brevemente el propósito del contrato.
* Identifica actores: owner, users, terceros, protocolos externos.
* Identifica flujo principal de fondos y estado.

### 2. ANÁLISIS DE SEGURIDAD (OWASP + SWC)
Analiza el código buscando vulnerabilidades en:
* Reentrancy, Access Control / Authorization, Integer / Logic Errors.
* Unsafe External Calls, Front-running / MEV, Oracle manipulation.
* Economic attacks (drain, inflation, unfair payouts), DoS vectors.
* Delegatecall / upgrade risks, Business logic inconsistencies.

**IMPORTANTE:**
* Referencia **SWC Registry** cuando sea posible.
* Asigna categoría **OWASP Smart Contract Top 10 2026**.
* Explica la **causa raíz (root cause)**.

### 3. ANÁLISIS DE LÓGICA DE NEGOCIO
Evalúa específicamente:
* Fallos en reglas del protocolo.
* Abuso de permisos administrativos.
* Inconsistencias en el flujo económico.
* Posibles ataques económicos (drain, griefing, unfair distribution).
* Dependencia de variables no utilizadas o mal implementadas.

### 4. CLASIFICACIÓN DE VULNERABILIDADES
Presenta TODOS los hallazgos en una tabla con este formato:

| Riesgo | Descripción | Severidad | SWC ID | OWASP Category | Vector de ataque |
| :--- | :--- | :--- | :--- | :--- | :--- |

**SEVERIDAD DEBE SER UNA DE:** Critical, High, Medium, Low.

### 5. REGLAS DE CONSISTENCIA (MUY IMPORTANTE)
* No inventes vulnerabilidades que no existan.
* No omitas vulnerabilidades evidentes.
* Si no aplica una categoría, indica "N/A".
* Mantén criterios consistentes de severidad.
* Prioriza explotabilidad real (no teórica).

### 6. SALIDA FINAL OBLIGATORIA
Después de la tabla incluye:

**BENCHMARK METRICS:**
* Time_seconds: (estimación del tiempo de análisis)
* Confidence: (0 a 1)
* Total_findings: (número total de vulnerabilidades)
* Critical: X
* High: X
* Medium: X
* Low: X
* Precision_estimate: (0 a 1, subjetivo)
* Coverage_estimate: (0 a 1, porcentaje del contrato analizado)
* Risk_score: (0 a 100 basado en severidad agregada)


### 7. GOLD STANDARD EVALUATION
Si se proporciona ground truth, compara:
* TP (True Positives), FP (False Positives), FN (False Negatives).
* Calcula: Precision, Recall, F1-score.

**Formato obligatorio:**
**GOLD STANDARD EVALUATION:**
* TP: X
* FP: X
* FN: X
* Precision: X
* Recall: X
* F1: X

Todo el contenido del informe debe ser generado con una estructura clara y muy visual.
---

## CONTRATO A ANALIZAR:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

[PEGAR AQUI EL CONTRATO]

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
Analiza el código buscando vulnerabilidades según esta clasificación: 

**Importante usar esta categoría  **OWASP Smart Contract Top 10 2026**:

* SC01:2026 Access Control:  Fallos en la granularidad de los permisos del contrato, permitiendo a entidades no autorizadas invocar funciones de administración críticas debido a la omisión o mala configuración de modificadores de estado. 
* SC02:2026 Business Logic Errors: Desconexión entre la intención del sistema y la ejecución algorítmica real del código. El programa es válido sintácticamente pero expone fallos en el diseño de sus flujos transaccionales.
* SC03:2026 Price Oracle Manipulation:Vulnerabilidad que ocurre cuando el contrato confía de manera ingenua en fuentes de datos u oráculos centralizados o fácilmente manipulables mediante variaciones abruptas de liquidez. 
* SC04:2026 Flash Loan-Facilitated Attacks: Explotación de la liquidez temporal masiva que proporcionan los préstamos relámpago en una misma transacción, utilizándola para alterar los equilibrios de precio en fondos de liquidez (pools) y arbitrage malicioso. 
* SC05:2026 Lack of Input Validation: Ausencia de restricciones operativas en los argumentos de entrada de las funciones públicas, abriendo la puerta a datos corruptos o desbordamientos de parámetros.
* SC06:2026 Uncheked External Calls: Transferencia de flujo de control a contratos de terceros sin validar el valor de retorno del éxito de la llamada (low-level calls), lo que desestabiliza el estado interno del contrato emisor si la llamada falla. 
* SC07:2026 Arithmetic Errors: Errores de lógica matemática derivados de truncamientos en divisiones o imprecisiones en el manejo de puntos fijos dentro de la EVM, a pesar de las protecciones nativas contra desbordamientos.
* SC08:2026 Reentracy Attacks: Vulnerabilidad clásica en la que un contrato externo malicioso interrumpe la ejecución de una transferencia y vuelve a invocar recursivamente la función de retiro antes de que el contrato de origen pueda actualizar su balance de estado. 
* SC09:2026 Integer Overflow and Underflkow: Desbordamiento numérico por almacenamiento matemático fuera de los rangos de representación de las variables primitivas (por ejemplo, uint256), relevante especialmente en bases de código heredadas o que utilizan bloques unchecked de forma insegura.
* SC10:2026 Proxy & Upgradeability Vulnerabilities: Fallos de seguridad derivados del uso de contratos proxy, colisión de almacenamiento (storage collisions) o inicializaciones defectuosas que permiten el secuestro de la lógica del contrato de implementación

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

Por último, genera además PDF de una sola página con un resumen visual de la auditoría.

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

---

## CONTRATO A ANALIZAR:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

[PEGAR AQUI EL CONTRATO]

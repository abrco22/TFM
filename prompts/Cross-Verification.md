# Prompt de Verificación Cruzada (Cross-Verification)

Actúa como un auditor senior de seguridad de Smart Contracts especializado en **OWASP Smart Contract Top 10** y **SWC Registry**.

## Tarea
Se te proporcionará un contrato inteligente en Solidity y un análisis de vulnerabilidades previo realizado por otro modelo de IA. Tu objetivo es realizar una **VERIFICACIÓN CRUZADA** imparcial y rigurosa.

---

## PROTOCOLO OBLIGATORIO

### 1. REANÁLISIS INDEPENDIENTE
* Analiza el contrato desde cero, sin sesgos.
* Identifica todas las vulnerabilidades reales.
* No te bases inicialmente en el anÃ¡lisis proporcionado.

### 2. COMPARACION CON EL ANALISIS ORIGINAL
Para cada hallazgo del otro modelo, clasifica:
* âœ… **CORRECTO** (verdadera vulnerabilidad).
* âŒ **FALSO POSITIVO** (no es vulnerabilidad real).
* âš ï¸ **INCOMPLETO** (parcialmente correcto pero mal explicado).
* ðŸš© **FALTA DETECTADA** (vulnerabilidad real omitida por el modelo original).

### 3. MAPEO OWASP + SWC
Para cada vulnerabilidad vÃ¡lida, asigna:
* **SWC ID** (si aplica).
* **Categorí­a OWASP Smart Contract Top 10**.
* **Severidad** (Critical / High / Medium / Low).
* Justificación técnica breve.

### 4. EVALUACIÓN DE CALIDAD DEL ANÁLISIS ORIGINAL
Evalúa el análisis recibido bajo los siguientes criterios (0 a 1):
* Precisión técnica, Cobertura, Consistencia en severidad.
* Calcula: Tasa de falsos positivos y Tasa de falsos negativos.

### DETECCION DE DISCREPANCIAS CRITICAS
Identifica explí­citamente:
* Vulnerabilidades crí­ticas ignoradas por el original.
* Bugs inexistentes reportados erróneamente como críticos.
* Errores de interpretación de lógica de negocio o riesgos económicos.

### 6. OUTPUT OBLIGATORIO

**A) Tabla de verificación:**
| Hallazgo | Estado | SWC | OWASP Category | Severidad | Comentario |
| :--- | :--- | :--- | :--- | :--- | :--- |

**B) Resumen de discrepancias:**
* True Positives: X
* False Positives: X
* False Negatives: X

**C) Métricas de evaluación del anélisis original:**
* Precision_estimate (0â€“1): X
* Recall_estimate (0â€“1): X
* F1_estimate (0â€“1): X
* Confidence_in_evaluation (0â€“1): X

**D) Benchmark Metrics del proceso de verificación:**
* Time_seconds: X
* Agreement_rate: X
* Disagreement_rate: X
* Critical_missed: X

### 7. CONCLUSION FINAL
* Â¿Es el análisis original confiable?
* Â¿Qué tipos de errores sistemáticos comete el modelo evaluado?
* Â¿Requiere el contrato revisión humana adicional tras esta verificación?

---

## CONTRATO A ANALIZAR:
```[PEGAR CONTRATO AQUI]


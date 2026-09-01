from typing import Dict, Any, List, Tuple, Optional

# Non-Negotiable International Maritime Boundary Line (IMBL) Invariants
CRITICAL_IMBL_DISTANCE_KM = 2.0   # Red Line: Immediate retreat required
WARNING_IMBL_DISTANCE_KM = 5.0    # Amber Line: Advisory buffer zone
CRITICAL_TIME_TO_BREACH_MIN = 5.0 # Imminent boundary crossing
WARNING_TIME_TO_BREACH_MIN = 15.0 # Projected boundary crossing window

class BoundaryGuardrailValidator:
    """
    Deterministically evaluates spatial proximity to the International Maritime Boundary Line.
    Prevents LLM from authorizing voyages or giving advice that risks border violations.
    """

    @staticmethod
    def evaluate(boundary_metrics: Dict[str, Any]) -> Tuple[bool, List[str], bool, str, Optional[float]]:
        """
        Evaluates boundary invariants.
        Returns:
            is_valid (bool): True if vessel is outside all danger zones.
            violations (List[str]): Explanations of violated spatial buffers.
            is_emergency (bool): True if immediate evasive maneuvering is required.
            emergency_message (str): Deterministic warning message for crew.
            evasive_heading (Optional[float]): Safe compass bearing to steer away from border.
        """
        violations: List[str] = []
        is_emergency = False
        emergency_msg = ""
        evasive_heading: Optional[float] = None

        if not boundary_metrics:
            return True, violations, False, "", None

        dist_km = boundary_metrics.get("distance_to_imbl_km", 999.0)
        breach_projected = boundary_metrics.get("lookahead_breach_projected", False)
        time_to_breach = boundary_metrics.get("time_to_breach_minutes")
        evasive_heading = boundary_metrics.get("evasive_heading_deg")

        # 1. Proximity Buffer Violation Checks
        if dist_km < CRITICAL_IMBL_DISTANCE_KM:
            violations.append(
                f"CRITICAL IMBL PROXIMITY: Vessel is {dist_km:.2f} km from International Maritime Boundary "
                f"(Hard Safety Limit: {CRITICAL_IMBL_DISTANCE_KM} km)."
            )
            is_emergency = True
            emergency_msg = (
                f"CRITICAL BORDER WARNING! You are within {dist_km:.1f} km of the IMBL. "
                f"Steer immediately to evasive heading {evasive_heading or 0:.0f}° to prevent international violation!"
            )
        elif dist_km < WARNING_IMBL_DISTANCE_KM:
            violations.append(
                f"IMBL BUFFER ADVISORY: Vessel is {dist_km:.2f} km from boundary line (Warning Zone: {WARNING_IMBL_DISTANCE_KM} km)."
            )

        # 2. Predictive 15-Minute Lookahead Vector Checks
        if breach_projected and time_to_breach is not None:
            if time_to_breach <= CRITICAL_TIME_TO_BREACH_MIN:
                violations.append(
                    f"IMMINENT IMBL BREACH: Projected border crossing in {time_to_breach:.1f} minutes at current speed & heading!"
                )
                is_emergency = True
                if not emergency_msg:
                    emergency_msg = (
                        f"EMERGENCY DRIFT WARNING! Border breach projected in {time_to_breach:.1f} mins. "
                        f"Alter course to {evasive_heading or 0:.0f}° immediately!"
                    )
            elif time_to_breach <= WARNING_TIME_TO_BREACH_MIN:
                violations.append(
                    f"IMBL DRIFT WARNING: Vessel heading leads to boundary crossing in {time_to_breach:.1f} minutes."
                )

        is_valid = len(violations) == 0
        return is_valid, violations, is_emergency, emergency_msg, evasive_heading

boundary_guardrail = BoundaryGuardrailValidator()

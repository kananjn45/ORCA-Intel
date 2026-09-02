from typing import Dict, Any, List, Tuple

# Hard Meteorological Safety Invariant Ceilings (ISRO / INCOIS Small Craft Marine Standards)
CRITICAL_WAVE_HEIGHT_M = 2.5      # Capsize danger threshold for small fiber crafts (< 10m)
WARNING_WAVE_HEIGHT_M = 2.0       # Caution threshold for artisanal boats
CRITICAL_WIND_SPEED_KNOTS = 25.0  # Squall / gale hazard threshold
WARNING_WIND_SPEED_KNOTS = 20.0   # Strong breeze caution threshold
CRITICAL_SWELL_HEIGHT_M = 2.0     # Long-period swell surge danger

class WeatherGuardrailValidator:
    """
    Deterministically evaluates weather & sea state metrics against invariant physics limits.
    Prevents LLM from recommending voyages during hazardous maritime sea states.
    """

    @staticmethod
    def evaluate(weather_data: Dict[str, Any]) -> Tuple[bool, List[str], bool, str]:
        """
        Evaluates weather invariants.
        Returns:
            is_valid (bool): True if no safety thresholds were breached.
            violations (List[str]): Explanations of breached thresholds.
            is_emergency (bool): True if critical abort/return action is required.
            emergency_message (str): Deterministic warning message for crew.
        """
        violations: List[str] = []
        is_emergency = False
        emergency_msg = ""

        if not weather_data:
            return True, violations, False, ""

        wave_height = weather_data.get("wave_height_m", 0.0)
        swell_height = weather_data.get("swell_wave_height_m", 0.0)
        wind_speed = weather_data.get("wind_speed_knots", 0.0)

        # 1. Significant Wave Height Invariants
        if wave_height > CRITICAL_WAVE_HEIGHT_M:
            violations.append(
                f"CRITICAL SEA STATE: Significant wave height {wave_height:.1f}m exceeds "
                f"maximum safe craft limit ({CRITICAL_WAVE_HEIGHT_M}m)."
            )
            is_emergency = True
            emergency_msg = (
                f"DANGER: Wave height {wave_height:.1f}m exceeds safe limits! "
                "High capsize risk. Return to nearest harbor immediately."
            )
        elif wave_height > WARNING_WAVE_HEIGHT_M:
            violations.append(
                f"WEATHER ADVISORY: Wave height {wave_height:.1f}m requires caution for artisanal craft."
            )

        # 2. Surface Wind Velocity Invariants
        if wind_speed > CRITICAL_WIND_SPEED_KNOTS:
            violations.append(
                f"CRITICAL SQUALL: Surface wind {wind_speed:.1f} kts exceeds "
                f"maximum operating ceiling ({CRITICAL_WIND_SPEED_KNOTS} kts)."
            )
            is_emergency = True
            if not emergency_msg:
                emergency_msg = (
                    f"DANGER: Severe wind speed {wind_speed:.1f} knots detected! "
                    "Squall conditions. Seek coastal shelter."
                )
        elif wind_speed > WARNING_WIND_SPEED_KNOTS:
            violations.append(
                f"WIND ADVISORY: Wind speed {wind_speed:.1f} kts exceeds normal calm limits."
            )

        # 3. Swell Wave Invariant
        if swell_height > CRITICAL_SWELL_HEIGHT_M:
            violations.append(
                f"HAZARDOUS SWELL: Swell height {swell_height:.1f}m poses severe grounding and surf danger."
            )

        is_valid = len(violations) == 0
        return is_valid, violations, is_emergency, emergency_msg

weather_guardrail = WeatherGuardrailValidator()

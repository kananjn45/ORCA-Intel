from typing import List, Dict, Any
from app.agents.state import AgentState
from app.agents.guardrails.weather_limits import weather_guardrail
from app.agents.guardrails.boundary_rules import boundary_guardrail

class DeterministicSymbolicGuardrail:
    """
    The Master Neuro-Symbolic Safety Barrier for ORCA.
    Intercepts and deterministically verifies all multi-agent state outputs before
    LLM response synthesis is permitted.
    """

    def verify(self, state: AgentState) -> AgentState:
        """
        Executes non-negotiable invariant tests across weather, boundaries, and routing.
        Mutates state with verification results and emergency status flags.
        """
        all_violations: List[str] = []
        is_emergency = False
        emergency_messages: List[str] = []

        # 1. Weather Invariants Evaluation
        weather_data = state.get("weather_data")
        if weather_data:
            w_valid, w_violations, w_emergency, w_msg = weather_guardrail.evaluate(weather_data)
            all_violations.extend(w_violations)
            if w_emergency:
                is_emergency = True
                if w_msg:
                    emergency_messages.append(w_msg)

        # 2. Boundary & IMBL Invariants Evaluation
        boundary_metrics = state.get("boundary_metrics")
        if boundary_metrics:
            b_valid, b_violations, b_emergency, b_msg, _ = boundary_guardrail.evaluate(boundary_metrics)
            all_violations.extend(b_violations)
            if b_emergency:
                is_emergency = True
                if b_msg:
                    emergency_messages.append(b_msg)

        # 3. Route Geometric Integrity Evaluation
        route_data = state.get("route_data")
        if route_data:
            is_route_safe = route_data.get("is_safe", True)
            min_imbl_dist = route_data.get("min_distance_to_imbl_along_route_km", 999.0)
            if not is_route_safe or min_imbl_dist < 2.0:
                all_violations.append(
                    f"ROUTE INVARIANT BREACH: Path approaches within {min_imbl_dist:.2f} km of IMBL "
                    "or intersects restricted maritime areas."
                )
                is_emergency = True
                emergency_messages.append("DANGER: Generated route violates maritime boundary buffer! Route discarded.")

        # Update AgentState with deterministic verification flags
        state["guardrail_passed"] = (len(all_violations) == 0)
        state["safety_violations"] = all_violations
        state["emergency_action_required"] = is_emergency
        
        if is_emergency and emergency_messages:
            state["emergency_advisory"] = " | ".join(emergency_messages)
        else:
            state["emergency_advisory"] = None

        return state

# Singleton instance
symbolic_verifier = DeterministicSymbolicGuardrail()

def symbolic_guardrail_node(state: AgentState) -> AgentState:
    """
    LangGraph node function executing deterministic symbolic safety verification.
    """
    return symbolic_verifier.verify(state)

from typing import Literal, Any, Dict
from backend.app.agents.state import AgentState
from backend.app.agents.nodes.intent_classifier import intent_classifier_node
from backend.app.agents.nodes.weather_agent import weather_agent_node
from backend.app.agents.nodes.pfz_agent import pfz_agent_node
from backend.app.agents.nodes.boundary_agent import boundary_agent_node
from backend.app.agents.nodes.routing_agent import routing_agent_node
from backend.app.agents.nodes.synthesizer import response_synthesizer_node
from backend.app.agents.guardrails.symbolic_verifier import symbolic_guardrail_node

try:
    from langgraph.graph import StateGraph, END
    HAS_LANGGRAPH = True
except ImportError:
    HAS_LANGGRAPH = False
    StateGraph = None
    END = "__end__"

# Localized emergency templates for deterministic override
EMERGENCY_LOCALIZED_MAP = {
    "ta": "🚨 தீவிர அவசர எச்சரிக்கை! {advisory} உடனடியாக உங்கள் படகை பாதுகாப்பான திசையில் திருப்பவும்!",
    "te": "🚨 అత్యవసర హెచ్చరిక! {advisory} వెంటనే సురక్షిత తీరానికి మళ్లించండి!",
    "hi": "🚨 गंभीर आपातकालीन चेतावनी! {advisory} तुरंत नाव को सुरक्षित दिशा में मोड़ें!",
    "bn": "🚨 জরুরী বিপদ সতর্কবার্তা! {advisory} অবিলম্বে নিরাপদ দিকে ফিরে আসুন!",
    "gu": "🚨 ગંભીર કટોકટી ચેતવણી! {advisory} તરત જ બોટને સલામત દિશામાં વાળો!",
    "en": "🚨 CRITICAL EMERGENCY OVERRIDE! {advisory} Execute evasive action immediately!"
}

def emergency_override_node(state: AgentState) -> AgentState:
    """
    Deterministically overrides and preempts LLM generation when invariant safety limits fail.
    Guarantees 100% zero-hallucination, high-priority emergency directives.
    """
    lang = state.get("source_language", "ta")
    if lang not in EMERGENCY_LOCALIZED_MAP:
        lang = "en"

    advisory = state.get("emergency_advisory") or "Maritime safety invariants breached."
    b_metrics = state.get("boundary_metrics") or {}
    evasive_heading = b_metrics.get("evasive_heading_deg", 270.0)

    # 1. Deterministic English Advisory
    state["english_response"] = (
        f"CRITICAL SAFETY OVERRIDE: {advisory} "
        f"Recommend immediate evasive bearing to {evasive_heading:.0f}°."
    )

    # 2. Deterministic Localized Regional Spoken Directive
    state["localized_response"] = EMERGENCY_LOCALIZED_MAP[lang].format(
        advisory=advisory
    )

    # 3. Emergency Action Quick-Replies for Mobile UI
    state["quick_replies"] = [
        f"Steer Bearing {evasive_heading:.0f}°",
        "Navigate to Nearest Harbor",
        "Acknowledge Emergency Alarm"
    ]

    return state

def evaluate_guardrail_condition(state: AgentState) -> Literal["emergency_override", "response_synthesizer"]:
    """
    Conditional routing function inspecting the output of the symbolic guardrail.
    """
    if state.get("emergency_action_required", False):
        return "emergency_override"
    return "response_synthesizer"

class StandaloneOrcaPipeline:
    """
    Deterministic DAG executor used when running in environments prior to LangGraph package installation.
    Implements the identical StateGraph execution semantics and conditional branching.
    """
    def invoke(self, state: AgentState) -> AgentState:
        s = dict(state)
        s = intent_classifier_node(s)
        s = weather_agent_node(s)
        s = pfz_agent_node(s)
        s = boundary_agent_node(s)
        s = routing_agent_node(s)
        s = symbolic_guardrail_node(s)
        branch = evaluate_guardrail_condition(s)
        if branch == "emergency_override":
            s = emergency_override_node(s)
        else:
            s = response_synthesizer_node(s)
        return s

def build_orca_agent_graph():
    """
    Constructs and compiles the ORCA Multi-Agent LangGraph workflow with Neuro-Symbolic Safety Guards.
    
    Graph Topology:
      [START] 
         │
         ▼
      intent_classifier ──> weather_agent ──> pfz_agent ──> boundary_agent ──> routing_agent
                                                                                    │
                                                                                    ▼
                                                                           symbolic_guardrail
                                                                                    │
                                          ┌─────────────────────────────────────────┴─────────────────────────────────────────┐
                         (emergency_action_required == True)                                                 (emergency_action_required == False)
                                          │                                                                                   │
                                          ▼                                                                                   ▼
                                 emergency_override                                                                  response_synthesizer
                                          │                                                                                   │
                                          ▼                                                                                   ▼
                                        [END]                                                                               [END]
    """
    if not HAS_LANGGRAPH:
        return StandaloneOrcaPipeline()

    workflow = StateGraph(AgentState)

    # Register Nodes
    workflow.add_node("intent_classifier", intent_classifier_node)
    workflow.add_node("weather_agent", weather_agent_node)
    workflow.add_node("pfz_agent", pfz_agent_node)
    workflow.add_node("boundary_agent", boundary_agent_node)
    workflow.add_node("routing_agent", routing_agent_node)
    workflow.add_node("symbolic_guardrail", symbolic_guardrail_node)
    workflow.add_node("emergency_override", emergency_override_node)
    workflow.add_node("response_synthesizer", response_synthesizer_node)

    # Setup Sequential Processing Pipeline
    workflow.set_entry_point("intent_classifier")
    workflow.add_edge("intent_classifier", "weather_agent")
    workflow.add_edge("weather_agent", "pfz_agent")
    workflow.add_edge("pfz_agent", "boundary_agent")
    workflow.add_edge("boundary_agent", "routing_agent")
    workflow.add_edge("routing_agent", "symbolic_guardrail")

    # Add Conditional Safety Branching
    workflow.add_conditional_edges(
        "symbolic_guardrail",
        evaluate_guardrail_condition,
        {
            "emergency_override": "emergency_override",
            "response_synthesizer": "response_synthesizer"
        }
    )

    # Terminal Edges
    workflow.add_edge("emergency_override", END)
    workflow.add_edge("response_synthesizer", END)

    return workflow.compile()

# Master compiled graph runnable with active symbolic safety guardrails
orca_graph = build_orca_agent_graph()

#!/usr/bin/env python3
"""
Demonstrate connected decision tree structure (without cycles for ASCII display)
"""

print("🌳 Connected Work Session Decision Tree")
print("=" * 60)
print()
print("This tree shows how decisions should connect and flow:")
print()
print("📍 START")
print("│")
print("├─ [urgent items?] YES → Handle Urgent")
print("│                       │")  
print("│                       └─ [completed] ─┐")
print("│                                       │")
print("└─ [urgent items?] NO ─────────────────┐")
print("                                        │")
print("                                        ▼")
print("                              ⚡ ENERGY CHECK (Hub)")
print("                                   │   │   │")
print("                          ┌────────┘   │   └────────┐")
print("                          │             │            │")
print("                          ▼             ▼            ▼")
print("                     [high]        [medium]       [low]")
print("                   Deep Work    Routine Work   Admin Work")
print("                         │             │            │")
print("                         └─────────────┼────────────┘")
print("                                       │")
print("                                       ▼")
print("                               🛑 BREAK CHECK")
print("                                   │       │")
print("                              [yes]│       │[no]")
print("                                   │       │")
print("                                   ▼       ▼")
print("                            Take Break  TIME CHECK")
print("                                   │       │   │")
print("                            [refreshed]   │   │")
print("                                   │       │   │")
print("                                   └───────┘   │")
print("                                       │       │")
print("                                  [continue]   │[end day]")
print("                                       │       │")
print("                                       │       ▼")
print("                        ┌──────────────┘    Wrap Up")
print("                        │                      │")
print("                        └─► Back to         [done]")
print("                           ENERGY CHECK       │")
print("                              ▲               ▼")
print("                              │            📝 END")
print("                              │")
print("                        (CYCLE CONTINUES)")
print()
print("=" * 60)
print("💡 Key Connections:")
print("• Multiple paths lead to central ENERGY CHECK hub")
print("• Work sessions connect to BREAK CHECK")
print("• Break/Time decisions can loop back to ENERGY CHECK") 
print("• Only 'end day' and 'wrap up' are terminal states")
print("• This creates a natural work rhythm!")
print()
print("🔄 The tree forms cycles - you can keep working through")
print("   the day by returning to the energy assessment.")

# Also show the Mermaid version which handles cycles better
print("\n" + "=" * 60)
print("📊 Mermaid Diagram (handles cycles):")
print("=" * 60)

mermaid = """
graph TD
    A[Start Session] --> B{Urgent Items?}
    B -->|yes| C[Handle Urgent]
    B -->|no| D{Energy Level?}
    C -->|completed| D
    
    D -->|high| E[Deep Work]
    D -->|medium| F[Routine Work] 
    D -->|low| G[Admin Work]
    
    E -->|session done| H{Take Break?}
    F -->|session done| H
    G -->|session done| H
    
    H -->|yes| I[Take Break]
    H -->|no| J{End of Day?}
    I -->|refreshed| J
    
    J -->|no| D
    J -->|yes| K[Wrap Up]
    
    style D fill:#e1f5fe
    style H fill:#fff3e0
    style J fill:#f3e5f5
"""

print(mermaid)
print("\n💡 Save this as a .mmd file and view at https://mermaid.live/")
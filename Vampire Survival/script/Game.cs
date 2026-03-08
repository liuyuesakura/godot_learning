using Godot;

namespace VampireSurvival.script;

public partial class Game : Node
{

    public static Player Player {set; get;}
    
    public static PlayerManager PlayerManager {set; get; }
    
    public static LevelManager LevelManager {set; get; }
}
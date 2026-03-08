using Godot;

namespace VampireSurvival.script;

public partial class LevelManager: Node
{
    public LevelManager()
    {
        GD.Print("LevelManager ctor");
    }
    
    public int CurrentLevel { set; get; }
    
    public LevelConfig[] LevelConfigs { set; get; }

    public override void _Ready()
    {
        Game.LevelManager = this;
        CurrentLevel = 1234;
        // load level configs from csv
        OnLevelChanged += (level, prefix) =>
        {
            GD.Print($"{level}_{prefix}");
        };
    }

    public void SwitchToLevel(int level)
    {
        CurrentLevel = level;
        EmitSignalOnLevelChanged(CurrentLevel, "Level:");
        // EmitSignal(LevelManager.SignalName.OnLevelChanged, CurrentLevel);
        // this line can not raise a valid signal, wondering why. todo:
    }
    
    [Signal]
    public delegate void OnLevelChangedEventHandler(int currentLevel, string prefix = "Level:");
}

public class LevelConfig
{
    
}
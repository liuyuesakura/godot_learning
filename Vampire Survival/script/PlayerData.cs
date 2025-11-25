using Godot;

namespace VampireSurvival.script;

public class PlayerData(PlayerManager playerManager)
{
    [Export] public int MaxHp { get; set; } = 100;

    private int _currentHp;
    [Export] public int CurrentHp
    {
        get => _currentHp;
        set
        {
            _currentHp = Mathf.Clamp(value, 0, MaxHp);
            playerManager.EmitSignal(PlayerManager.SignalName.OnPlayerHpChanged, 
                _currentHp, MaxHp);
             if (_currentHp <= 0)
            {
                playerManager.EmitSignal(PlayerManager.SignalName.OnPlayerDeath);
            }
        }
    }

    [Export] public int Damage { get; set; } = 5;

    /// <summary>
    /// 持有金币（是否应该和HP/ATK等数值分开两个class来处理？）
    /// </summary>
    [Export] public int Gold { get; set; } = 0;
    
}
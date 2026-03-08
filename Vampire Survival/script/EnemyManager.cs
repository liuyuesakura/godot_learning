using System.Collections.Generic;
using Godot;
using VampireSurvival.Util;

namespace VampireSurvival.script;


public partial class EnemyManager : Node
{
    // todo : enemy pool 

    private Dictionary<string, ObjectPool<BaseEnemy>> EnemyPools = 
        new Dictionary<string, ObjectPool<BaseEnemy>>();


    public override void _Ready()
    {
        // load all enemy prefab into pool
        
    }
}

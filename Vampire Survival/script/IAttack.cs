using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace VampireSurvival.script
{
    public interface IAttack
    {
        int DoAttack(Node2D origin, Node2D target, int damage);
    }
}

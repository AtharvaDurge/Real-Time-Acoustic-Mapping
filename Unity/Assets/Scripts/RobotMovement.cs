using UnityEngine;
using UnityEngine.InputSystem;

public class RobotMovement : MonoBehaviour
{
    public float speed = 3f;
    public float minX = -4.75f, maxX = 4.75f;
    public float minY = -3.75f, maxY = 3.75f;

    void Update()
    {
        if (Keyboard.current == null) return;

        Vector2 input = Vector2.zero;
        if (Keyboard.current.wKey.isPressed || Keyboard.current.upArrowKey.isPressed) input.y += 1;
        if (Keyboard.current.sKey.isPressed || Keyboard.current.downArrowKey.isPressed) input.y -= 1;
        if (Keyboard.current.aKey.isPressed || Keyboard.current.leftArrowKey.isPressed) input.x -= 1;
        if (Keyboard.current.dKey.isPressed || Keyboard.current.rightArrowKey.isPressed) input.x += 1;

        if (input.sqrMagnitude > 1f) input.Normalize();

        transform.position += (Vector3)(input * speed * Time.deltaTime);

        Vector3 p = transform.position;
        p.x = Mathf.Clamp(p.x, minX, maxX);
        p.y = Mathf.Clamp(p.y, minY, maxY);
        transform.position = p;
    }
}

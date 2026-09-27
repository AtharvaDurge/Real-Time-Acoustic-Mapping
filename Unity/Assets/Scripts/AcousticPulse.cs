using UnityEngine;

public class AcousticPulse : MonoBehaviour
{
    public float speed = 3f;
    public float maxRadius = 5f;

    private float radius;
    private LineRenderer ring;

    void Awake()
    {
        ring = GetComponent<LineRenderer>();

        if (ring == null)
            ring = gameObject.AddComponent<LineRenderer>();

        ring.useWorldSpace = false;
        ring.loop = true;
        ring.positionCount = 64;
        ring.startWidth = 0.025f;
        ring.endWidth = 0.025f;
        ring.material = new Material(Shader.Find("Sprites/Default"));
        ring.startColor = new Color(1f, 0.8f, 0f, 0.65f);
        ring.endColor = new Color(1f, 0.8f, 0f, 0.65f);
    }

    void Update()
    {
        radius += speed * Time.deltaTime;
        DrawRing(radius);

        float alpha = Mathf.Clamp01(1f - radius / maxRadius);
        Color c = new Color(1f, 0.8f, 0f, 0.65f * alpha);
        ring.startColor = c;
        ring.endColor = c;

        if (radius >= maxRadius)
            Destroy(gameObject);
    }

    void DrawRing(float r)
    {
        for (int i = 0; i < 64; i++)
        {
            float a = 2f * Mathf.PI * i / 64f;
            ring.SetPosition(i, new Vector3(Mathf.Cos(a) * r, Mathf.Sin(a) * r, 0f));
        }
    }
}

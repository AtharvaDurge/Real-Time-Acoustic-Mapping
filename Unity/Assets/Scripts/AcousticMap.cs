using System.Collections.Generic;
using UnityEngine;

public class AcousticMap : MonoBehaviour
{
    public float pointSize = 0.045f;
    public Color pointColor = Color.yellow;
    public int maxPoints = 2500;

    private readonly List<GameObject> points = new List<GameObject>();
    private Sprite dotSprite;

    void Awake()
    {
        dotSprite = CreateDotSprite();
    }

    public void AddPoint(Vector2 position)
    {
        GameObject point = new GameObject("AcousticMapPoint");
        SpriteRenderer sr = point.AddComponent<SpriteRenderer>();
        sr.sprite = dotSprite;
        sr.color = pointColor;
        sr.sortingOrder = 5;

        point.transform.position = new Vector3(position.x, position.y, 0f);
        point.transform.localScale = Vector3.one * pointSize;

        points.Add(point);

        if (points.Count > maxPoints)
        {
            Destroy(points[0]);
            points.RemoveAt(0);
        }
    }

    Sprite CreateDotSprite()
    {
        Texture2D texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
        texture.SetPixel(0, 0, Color.white);
        texture.Apply();

        return Sprite.Create(texture, new Rect(0, 0, 1, 1),
            new Vector2(0.5f, 0.5f), 1f);
    }

    public void ClearMap()
    {
        foreach (GameObject p in points)
            if (p != null) Destroy(p);
        points.Clear();
    }
}

using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using UnityEngine;

public class AcousticRobotClient : MonoBehaviour
{
    [Header("MATLAB UDP")]
    public string matlabHost = "127.0.0.1";
    public int matlabPort = 55000;
    public int unityPort = 55001;

    [Header("Robot / Scan")]
    public Transform robot;
    public int raysPerScan = 72;
    public float maxRange = 10f;
    public float scanInterval = 1.5f;

    [Header("Wall Layer")]
    public LayerMask wallLayer;

    [Header("Visualization")]
    public AcousticMap map;
    public GameObject pulsePrefab;
    public float pulseSpeed = 3f;
    public float pulseMaxRadius = 5f;

    [Header("Console")]
    public bool showScanMessages = true;

    private UdpClient udpClient;
    private IPEndPoint matlabEndPoint;
    private float scanTimer;
    private bool initialized;

    private void Start()
    {
        if (robot == null)
            robot = transform;

        InitializeUDP();
    }

    private void InitializeUDP()
    {
        try
        {
            udpClient = new UdpClient(unityPort);

            matlabEndPoint = new IPEndPoint(
                IPAddress.Parse(matlabHost),
                matlabPort
            );

            initialized = true;

            Debug.Log("==============================================");
            Debug.Log("ACOUSTIC DSP UDP CLIENT STARTED");
            Debug.Log("Unity UDP Port : " + unityPort);
            Debug.Log("MATLAB         : " + matlabHost + ":" + matlabPort);
            Debug.Log("==============================================");
        }
        catch (Exception e)
        {
            Debug.LogError(
                "UDP INITIALIZATION FAILED: " + e.Message
            );
        }
    }

    private void Update()
    {
        if (!initialized)
            return;

        ReceiveMATLABData();

        scanTimer += Time.deltaTime;

        if (scanTimer >= scanInterval)
        {
            scanTimer = 0f;
            SendAcousticScan();
        }
    }

    private void SendAcousticScan()
    {
        StringBuilder message = new StringBuilder();

        message.Append("SCAN ");

        int hitCount = 0;
        int missCount = 0;

        float nearestDistance = maxRange;
        float farthestDistance = 0f;

        for (int i = 0; i < raysPerScan; i++)
        {
            float angle =
                -180f +
                (360f / raysPerScan) * i;

            float radians =
                angle * Mathf.Deg2Rad;

            Vector2 direction = new Vector2(
                Mathf.Cos(radians),
                Mathf.Sin(radians)
            ).normalized;

            Vector2 origin = robot.position;

            RaycastHit2D hit = Physics2D.Raycast(
                origin,
                direction,
                maxRange,
                wallLayer
            );

            float distance;

            if (hit.collider != null)
            {
                distance = hit.distance;
                hitCount++;

                if (distance < nearestDistance)
                    nearestDistance = distance;

                if (distance > farthestDistance)
                    farthestDistance = distance;

                // Draw the ray in Scene view
                Debug.DrawRay(
                    origin,
                    direction * distance,
                    Color.green,
                    scanInterval
                );
            }
            else
            {
                distance = maxRange;
                missCount++;

                Debug.DrawRay(
                    origin,
                    direction * maxRange,
                    Color.red,
                    scanInterval
                );
            }

            distance = Mathf.Clamp(
                distance,
                0.05f,
                maxRange
            );

            message.Append(
                angle.ToString("F2")
            );

            message.Append(",");

            message.Append(
                distance.ToString("F3")
            );

            message.Append(";");
        }

        string scanMessage = message.ToString();

        byte[] data =
            Encoding.ASCII.GetBytes(scanMessage);

        try
        {
            int bytesSent = udpClient.Send(
                data,
                data.Length,
                matlabEndPoint
            );

            Debug.Log(
                "=============================================="
            );

            Debug.Log(
                "ACOUSTIC SCAN"
            );

            Debug.Log(
                "Rays Hit Walls : " +
                hitCount +
                " / " +
                raysPerScan
            );

            Debug.Log(
                "Rays Missed    : " +
                missCount
            );

            Debug.Log(
                "Nearest Wall   : " +
                nearestDistance.ToString("F2") +
                " m"
            );

            Debug.Log(
                "Farthest Wall  : " +
                farthestDistance.ToString("F2") +
                " m"
            );

            Debug.Log(
                "UDP Sent       : " +
                bytesSent +
                " bytes"
            );

            Debug.Log(
                "=============================================="
            );
        }
        catch (Exception e)
        {
            Debug.LogError(
                "UDP SEND FAILED: " + e.Message
            );
        }

        CreatePulse();
    }

    private void CreatePulse()
    {
        GameObject pulseObject;

        if (pulsePrefab != null)
        {
            pulseObject = Instantiate(
                pulsePrefab,
                robot.position,
                Quaternion.identity
            );
        }
        else
        {
            pulseObject = new GameObject(
                "AcousticPulse_Runtime"
            );

            pulseObject.transform.position =
                robot.position;

            pulseObject.AddComponent<AcousticPulse>();
        }

        AcousticPulse pulse =
            pulseObject.GetComponent<AcousticPulse>();

        if (pulse != null)
        {
            pulse.speed = pulseSpeed;
            pulse.maxRadius = pulseMaxRadius;
        }
    }

    private void ReceiveMATLABData()
    {
        if (udpClient == null)
            return;

        try
        {
            while (udpClient.Available > 0)
            {
                IPEndPoint remote =
                    new IPEndPoint(
                        IPAddress.Any,
                        0
                    );

                byte[] data =
                    udpClient.Receive(ref remote);

                string message =
                    Encoding.ASCII.GetString(data).Trim();

                if (showScanMessages)
                {
                    Debug.Log(
                        "MATLAB -> UNITY: " +
                        message.Substring(
                            0,
                            Mathf.Min(
                                message.Length,
                                100
                            )
                        )
                    );
                }

                ProcessMATLABMeasurements(message);
            }
        }
        catch (SocketException)
        {
            // No data available.
        }
        catch (Exception e)
        {
            Debug.LogError(
                "UDP RECEIVE ERROR: " + e.Message
            );
        }
    }

    private void ProcessMATLABMeasurements(
        string message
    )
    {
        if (!message.StartsWith("MEAS"))
            return;

        string text =
            message.Substring(4).Trim();

        string[] measurements =
            text.Split(
                new char[] { ';' },
                StringSplitOptions.RemoveEmptyEntries
            );

        int pointCount = 0;

        foreach (string measurement in measurements)
        {
            string[] values =
                measurement.Split(',');

            if (values.Length != 2)
                continue;

            float angle;
            float distance;

            if (!float.TryParse(
                    values[0],
                    out angle))
                continue;

            if (!float.TryParse(
                    values[1],
                    out distance))
                continue;

            if (distance <= 0f ||
                distance > maxRange)
                continue;

            float radians =
                angle * Mathf.Deg2Rad;

            Vector2 direction =
                new Vector2(
                    Mathf.Cos(radians),
                    Mathf.Sin(radians)
                );

            Vector2 point =
                (Vector2)robot.position +
                direction * distance;

            if (map != null)
            {
                map.AddPoint(point);
                pointCount++;
            }
        }

        Debug.Log(
            "ACOUSTIC DSP: MATLAB returned " +
            pointCount +
            " detected points."
        );
    }

    private void OnApplicationQuit()
    {
        CloseUDP();
    }

    private void OnDestroy()
    {
        CloseUDP();
    }

    private void CloseUDP()
    {
        if (udpClient != null)
        {
            try
            {
                udpClient.Close();
            }
            catch
            {
            }

            udpClient = null;
        }

        initialized = false;
    }
}
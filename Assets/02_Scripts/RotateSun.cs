using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateSun : MonoBehaviour
{
    public float speed = 25f; 

    void Update()
    {
        transform.Rotate(speed * Time.deltaTime, speed * Time.deltaTime, 0);
    }
}

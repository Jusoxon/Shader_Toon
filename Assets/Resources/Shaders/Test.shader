/*주로 보고 공부해온 사이트 들 입니다.*/
//https://m.blog.naver.com/PostView.nhn?blogId=kzh8055&logNo=140188596379&proxyReferer=https%3A%2F%2Fwww.google.com%2F
//https://youtu.be/E3zHGD8V2IY
//https://docs.unity3d.com/kr/530/Manual/SL-ShaderPrograms.html

Shader "Custom/Test" {
	Properties
	{
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_SSSTex("SSS (RGB)", 2D) = "white" {}
		_ILMTex("ILM (RGB)", 2D) = "white" {}

		_Outline("Outline width", Range(.0, 2)) = .5
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_ShadowContrast("Vertex Shadow contrast", Range(0, 20)) = 1
		_DarkenInnerLineColor("Darken Inner Line Color", Range(0, 1)) = 0.2

		_LightDirection("Light Direction", Vector) = (0,0,1)
	}


	CGINCLUDE
	#include "UnityCG.cginc"
	sampler2D _MainTex;
	sampler2D _SSSTex;
	struct appdata
	{
		float4 vertex : POSITION;
		float3 normal : NORMAL;
		float4 texCoord : TEXCOORD0;
	};

	struct v2f	//vertex to fragment, 정점셰이더에서 프레그먼트(픽셀)셰이더로 넘어가는 데이터
	{
		float4 pos : POSITION;
		float4 color : COLOR;
		float4 tex : TEXCOORD0;
	};

	//uniform : 변수가 셰이더외부에서 초기화 되어 셰이더에 입력
	uniform float _Outline;
	uniform float4 _OutlineColor;
	uniform float _ShadowContrast;
	uniform float _DarkenInnerLineColor;
	uniform float3 _LightDirection;

	//외곽선 그리기
	v2f vert(appdata v)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		float3 norm = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal); //행렬로 변화
		float2 offset = TransformViewToProjection(norm.xy);
		o.pos.xy += offset * _Outline;
		o.tex = v.texCoord;

		o.color = _OutlineColor;
		return o;
	}
	ENDCG

	SubShader
	{
		CGPROGRAM
		#pragma surface surfA Lambert

		fixed4 _Color;

		struct Input {
			float2 uv_MainTex;
		};

		void surfA(Input IN, inout SurfaceOutput o) {
			float4 c2 = float4(1, 0, 1, 1);
			o.Albedo = c2.rgb;
			o.Alpha = c2.a;
		}
		ENDCG

		Pass
		{
			Name "OUTLINE"
			Tags{ "LightMode" = "Always" }
			Cull Front
			ZWrite On
			ColorMask RGB
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4 frag(v2f i) :COLOR
			{
				fixed4 light = tex2D(_MainTex, i.tex.xy);
				fixed4 sss = tex2D(_SSSTex, i.tex.xy);
				fixed4 dark = light * sss;
			
				dark = dark * 0.5f;
				dark.a = 1;
				return dark;
			}

			ENDCG
		}

		CGPROGRAM

		#pragma surface surf  CelShadingForward  vertex:vertB 
		#pragma target 3.0

		sampler2D _ILMTex;

		struct Input
		{
			float2 uv_MainTex;
			float3 vertexColor;
		};

		struct v2fB
		{
			float4 pos : SV_POSITION;
			fixed4 color : COLOR;
		};

		void vertB(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.vertexColor = v.color;
		}

		//새로 정의
		struct SurfaceOutputCustom
		{
			fixed3 Albedo;
			fixed3 Normal;
			fixed3 Emission;
			fixed Alpha;

			float3 BrightColor;
			float3 ShadowColor;
			float3 InnerLineColor;
			float ShadowThreshold;

			float SpecularIntensity;
			float SpecularSize;

		};

		float4 LightingCelShadingForward(SurfaceOutputCustom s, float3 lightDir, float atten)
		{

			float nDotL = dot(lightDir, s.Normal);
			float4 c = float4(0, 0, 0, 1);

			float4 specColor = float4(s.SpecularIntensity, s.SpecularIntensity, s.SpecularIntensity, 1);
			float blendArea = 0.04;


			nDotL -= s.ShadowThreshold;

			float specStrength = s.SpecularIntensity;
			if (nDotL < 0)
			{

				if (nDotL < -s.SpecularSize - 0.5f && specStrength <= 0.5f)
				{
					c.rgb = s.ShadowColor * (0.5f + specStrength);
				}
				else
				{
					c.rgb = s.ShadowColor;
				}
			}
			else
			{
				if (s.SpecularSize < 1 && nDotL * 1.8f > s.SpecularSize&& specStrength >= 0.5f)
				{
					c.rgb = s.BrightColor * (0.5f + specStrength);
				}
				else
				{
					c.rgb = s.BrightColor;
				}

			}
			c.rgb = c.rgb * s.InnerLineColor;

			return c;
		}

		void surf(Input IN, inout SurfaceOutputCustom  o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);

			fixed4 sss = tex2D(_SSSTex, IN.uv_MainTex);
			fixed4 ilm = tex2D(_ILMTex, IN.uv_MainTex);

			o.BrightColor = c.rgb;
			o.ShadowColor = c.rgb * sss.rgb;

			float clampedLineColor = ilm.a;
			if (clampedLineColor < _DarkenInnerLineColor)
				clampedLineColor = _DarkenInnerLineColor;

			o.InnerLineColor = float3(clampedLineColor, clampedLineColor, clampedLineColor);

			float vertColor = IN.vertexColor.r;
				o.ShadowThreshold = ilm.g;
				o.ShadowThreshold *= vertColor;
				o.ShadowThreshold = 1 - o.ShadowThreshold;


			o.SpecularIntensity = ilm.r;

			o.SpecularSize = 1 - ilm.b;

		}

		ENDCG

	}

	FallBack "Diffuse"
}

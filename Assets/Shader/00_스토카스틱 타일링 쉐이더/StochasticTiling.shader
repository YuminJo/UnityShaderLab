Shader "Custom/StochasticTiling"
{
    Properties
    {
        // 쉐이더에서 사용할 프로퍼티를 정의합니다.
        _BaseColor ("Base Color", 2D) = "white" {}
        _UVScale ("UV Scale", Float) = 1.0
    }

    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            // Pragma 는 컴파일러한테 전달하는 지시문입니다.
            // 버텍스 쉐이더에 vert 함수를, 프래그먼트 쉐이더에 frag 함수를 사용하겠다는 의미입니다.
            #pragma vertex Vert

            // Fragment Stage에 frag 함수를 사용하겠다는 의미입니다.
            #pragma fragment Frag

            // 유니티의 코어 라이브러리를 포함합니다.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 유니티의 기본 제공 함수들을 사용하기 위해 포함합니다.
            struct Attributes
            {
                float3 position : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
            };

            // 유니티의 네이밍 컨벤션에 따라 정의된 구조체입니다.
            // 인터폴레이터 역할을 합니다.
            struct Varyings
            {
                // 이게 없으면 유니티가 화면 상의 위치를 알 수 없습니다.
                float4 positionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
            };

            // 컨스턴트 버퍼는 쉐이더에 전달되는 데이터를 담고 있습니다.
            // 유니티는 자동으로 이 버퍼를 업데이트 해줍니다.
            cbuffer UnityPerMaterial
            {
                float _UVScale;
            };

            // 버텍스 쉐이더 스테이지는 Mesh를 기준으로 정점 하나당 한 번씩 호출됩니다.
            // 인터폴레이터는 버텍스 쉐이더에서 프래그먼트 쉐이더로 데이터를 전달하는 역할을 합니다.
            Varyings Vert(Attributes input)
            {
                float3 position = TransformObjectToWorld(input.position);

                Varyings output;
                // 월드 스페이스 위치를 클립 스페이스 위치로 변환합니다.
                output.positionCS = TransformWorldToHClip(position);
                output.uv0 = position.xz * _UVScale; // 타일링 효과를 위해 xz 좌표를 UV로 사용합니다.
                return output;
            }

            Texture2D _BaseColor;
            SamplerState sampler_BaseColor; //DirectX 11 이상부터는 샘플러를 따로 정의해줘야 합니다.

            // 프래그먼트 쉐이더는 픽셀 하나당 한 번씩 호출됩니다.
            // 픽쉘은 화면의 해상도에 따라 실행 횟수가 달라집니다.
            // half는 컬러값에, float은 위치값으로 쓴다. 컨벤션에 따라 다름.
            // return 값은 SV_Target 의미.
            half4 Frag(Varyings input) : SV_TARGET
            {
                float2 uv = input.uv0.xy;
                // int랑 int를 비교하기 위해 float2 -> int2 변환
                //float2 coord = int2(floor(uv)); // coordinates of the tile
                float2 coord = floor(uv); // coordinates of the tile

                // int로 캐스팅이랑은 다름. asuint는 비트 그대로 변환
                // coord.x 값을 해시 함수에 넣어서 랜덤한 float 값을 생성
                float2 jitter = float2(GenerateHashedRandomFloat(asuint(coord.x)),
                                       GenerateHashedRandomFloat(asuint(coord.y) ^ -asuint(coord.x))); // 작대기는 0부터 올라가기 때문에 생김 그래서 음수로 바꿔줌

                // sincos(x, out sinValue, out cosValue)
                // Radians 단위로 각도를 받아서 sin과 cos 값을 각각 출력 변수에 저장
                // sinValue = sin(radian);
                // cosValue = cos(radian);
                // 같은 효과
                float4 sc;
                sincos(jitter.xy * TWO_PI, sc.xy, sc.zw);
                float2x2 rotationX = float2x2(sc.x, sc.z, -sc.z, sc.x); //rotation matrix
                float2x2 rotationZ = float2x2(sc.y, sc.w, -sc.w, sc.y); //rotation matrix
                uv = mul(rotationX, uv); // 회전 변환 적용
                uv = mul(rotationZ, uv);

                half4 baseColor = _BaseColor.Sample(sampler_BaseColor, uv);
                return baseColor;
            }
            ENDHLSL
        }
    }
}

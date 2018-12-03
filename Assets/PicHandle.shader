Shader "Custom/PicHandle" {
		Properties {
			_MainTex("主纹理 (RGB)", 2D) = "white" {}
			[HDR]_MainColor("主颜色",Color)=(1,1,1,1)
			_OtherTex("副纹理（RGB）",2D) = "white"{}
			_BumpTex("副纹理（RGB）",2D) = "white"{}
			_LightTex("副纹理（RGB）",2D) = "white"{}
			[HDR]_RightColor("RigntTexColor",Color) = (1,1,1,1)
			_RightIterationNumber("右图迭代次数",Int) = 16
			_RightBlurCenterX("右图模糊中心X",Float) = 0.5
			_RightBlurIntensity("右图模糊权重",Range(0,0.05)) = 0.01
			_RightOffsetX("右图偏移量X",float) = 0
			[HDR]_Left2Color1("Left2TexColor1",Color) = (1,1,1,1)
			[HDR]_Left2Color2("Left2TexColor2",Color) = (1,1,1,1)
			_Left2IterationNumber("左二图迭代次数",Int) = 16
			_Left2BlurCenterX("左二图模糊中心X",float) = 0.5
			_Left2BlurIntensity("左二图模糊权重",Range(0,0.05)) = 0.01
			_Left2OffsetX("左二图偏移量X",float) = 0
			[HDR]_Left1Color("Left1TexColor",Color) = (1,1,1,1)
			_Left1IterationNumber("左一图迭代次数",Int) = 16
			_Left1BlurCenterX("左一图模糊中心X",float) = 0.5
			_Left1BlurIntensity("右图模糊权重",Range(0,0.05)) = 0.01
			_Left1OffsetX("左一图偏移量X",float) = 0
		}
		SubShader
		{
			//--------------------------------唯一的通道------------------------------- 
			//Tags{"RenderType"="AlphaTests"}
			ZTest Off
			//
			Blend SrcAlpha zero
			Pass
		{
			//设置深度测试模式:渲染所有像素.等同于关闭透明度测试（AlphaTest Off）  
			
			Fog{Mode Off}

			//===========开启CG着色器语言编写模块===========  
			CGPROGRAM

			//编译指令: 指定着色器编译目标为Shader Model 3.0  
			#pragma target 3.0  

			//编译指令:告知编译器顶点和片段着色函数的名称  
			#pragma vertex vert  
			#pragma fragment frag  

			//包含辅助CG头文件  
			#include "UnityCG.cginc"  

			//外部变量的声明  
			fixed4 _MainColor;
			uniform sampler2D _MainTex;
			float4 _MainTex_ST;
			uniform sampler2D _OtherTex;
			float4 _OtherTex_ST;
			sampler2D _BumpTex;
			float4 _BumpTex_ST;
			sampler2D _LightTex;
			float4 _LightTex_ST;
			float4 _MainTex_TexelSize;
			uniform float _intensity;
			uniform float _Left1BlurCenterX;
			uniform float _Left2BlurCenterX;
			uniform float _RightBlurCenterX;
			uniform int _RightIterationNumber;
			uniform int _Left2IterationNumber;
			uniform int _Left1IterationNumber;
			float _Left1OffsetX;
			float _Left2OffsetX;
			float _RightOffsetX;
			fixed _RightBlurIntensity;
			fixed _Left1BlurIntensity;
			fixed _Left2BlurIntensity;
			fixed4 _Left1Color;
			fixed4 _Left2Color1;
			fixed4 _Left2Color2;
			fixed4 _RightColor;
			float _BlurRadius;
			fixed4 XMotionBlur(float2 texCoord, float BlurCenterX, fixed intensity, int IterationNumber, sampler2D tex);
			fixed4 SimpleBlur(sampler2D tex,float2 texcoord);
			fixed4 ScreenBlend(fixed4 c1, fixed4 c2);
			fixed4 BlendAdd(fixed4 c1, fixed4 c2);
			fixed4 GetGrey(fixed4 c,float rate,fixed lineValue);
			fixed4 SoftLight(fixed4 c1, fixed4 c2);
			fixed4 FaceShadow(fixed4 c);
			fixed4 AddNormal(fixed4 sr, fixed4 dr);
			fixed4 gradient(fixed4 c1, fixed4 c2,float posX);

			//顶点输入结构  
			struct vertexInput
			{
				float4 vertex : POSITION;//顶点位置    
				float2 uv : TEXCOORD0;//一级纹理坐标  
			};
	
			//顶点输出结构  
			struct vertexOutput
			{
				float2 texcoordMain : TEXCOORD0;//主图纹理坐标  
				float2 texcoordRight : TEXCOORD1;//右图纹理坐标
				float2 texcoordLeft1 : TEXCOORD2;//左一图纹理坐标
				float2 texcoordLeft2: TEXCOORD3;//左二图纹理坐标
				float4 vertex : SV_POSITION;//像素位置    
				
			};
			



			//--------------------------------【顶点着色函数】-----------------------------  
			// 输入：顶点输入结构体  
			// 输出：顶点输出结构体  
			//---------------------------------------------------------------------------------  
			vertexOutput vert(vertexInput Input)
			{
				//【1】声明一个输出结构对象  
				vertexOutput Output;

				//【2】填充此输出结构  
				//输出的顶点位置为模型视图投影矩阵乘以顶点位置，也就是将三维空间中的坐标投影到了二维窗口  
				Output.vertex = UnityObjectToClipPos(Input.vertex);
				//输出的纹理坐标也就是输入的纹理坐标  
				Output.texcoordMain = TRANSFORM_TEX(Input.uv,_MainTex);
				 
				Output.texcoordRight = Input.uv * _MainTex_ST.xy + float2(_RightOffsetX,0);
				Output.texcoordLeft1 = Input.uv*_MainTex_ST.xy + float2(_Left1OffsetX, 0);
				Output.texcoordLeft2 = Input.uv*_OtherTex_ST.xy + float2(_Left2OffsetX, 0);
				
				//【3】返回此输出结构对象  
				return Output;
			}
	        
			//--------------------------------【片段着色函数】-----------------------------  
			// 输入：顶点输出结构体  
			// 输出：float4型的颜色值  
			//---------------------------------------------------------------------------------  
			fixed4 frag(vertexOutput i) : SV_Target
			{
				fixed4 colorMain;
				colorMain = tex2D(_MainTex, i.texcoordMain);
				colorMain = GetGrey(colorMain, 1.5, 0.9)*_MainColor;
				colorMain = FaceShadow(colorMain);
				
				
				
				fixed4 colorMainShadow = lerp(colorMain, fixed4(0, 0, 0, 1), max(0, (1 - 0.45) / 0.12*(i.texcoordMain.x - 0.45)));
				
				colorMain = colorMainShadow;

				//与右图叠加
				fixed4 colorRight;
				colorRight = XMotionBlur(i.texcoordRight, _RightBlurCenterX, _RightBlurIntensity, _RightIterationNumber, _MainTex)*20;

				colorRight = GetGrey(colorRight,1.2,0.9);
				
				
				fixed4 blendMR= ScreenBlend(colorMain,colorRight)*_RightColor;
				blendMR= lerp(fixed4(0, 0, 0, 1), blendMR,max(0, (1 -0.3) / 0.12*(i.texcoordMain.y -0.01)));
				fixed4 bumpColorR = tex2D(_BumpTex, i.texcoordRight);
				bumpColorR = GetGrey(bumpColorR, 0.7, 0.6);
				blendMR = fixed4(BlendAdd(blendMR, bumpColorR).rgb, 1);
				
				//blendMR *= colorRight1/5;
				fixed4 RMColor;
				RMColor = lerp(colorMain,blendMR,max(0,(1/(1-0.6))*(i.texcoordMain.x-0.6)));

				//与左二图叠加
				fixed4 colorLeft2;
				fixed4 colorLeft2Raw = XMotionBlur(i.texcoordLeft2, _Left2BlurCenterX, _Left2BlurIntensity, _Left2IterationNumber, _OtherTex);
				
				//colorLeft2 = SimpleBlur(_OtherTex,i.texcoordLeft2);
				colorLeft2 = GetGrey(colorLeft2Raw, 1, 0.5);
				colorLeft2 = lerp(fixed4(0.05, 0.05, 0.05, 1),colorLeft2, i.texcoordMain.y);
				colorLeft2 *= colorLeft2Raw*1.6*gradient(_Left2Color1,_Left2Color2,i.texcoordMain.x-0.35);
				
				fixed4 blendML2 =AddNormal(colorLeft2,colorMain);
				//blendML2=lerp(fixed4(0, 0, 0, 1), blendML2, max(0, (1 - 0.78) / 0.12*(i.texcoordMain.y )));
				fixed4 bumpColorL2 = tex2D(_BumpTex,i.texcoordLeft2);
				bumpColorL2 = GetGrey(bumpColorL2, 0.9, 0.6);
				blendML2 = fixed4(BlendAdd(blendML2, bumpColorL2).rgb,0.6);
				
				
				fixed4 L2MColor;
				L2MColor = lerp(RMColor, blendML2, max(0, (1 / (1 - 0.63))*(0.55 - i.texcoordMain.x)));

				//与左一图叠加
				fixed4 colorLeft1;
				colorLeft1 = XMotionBlur(i.texcoordLeft1, _Left1BlurCenterX, _Left1BlurIntensity, _Left1IterationNumber, _MainTex)*15;
				colorLeft1 = lerp(fixed4(0, 0, 0, 1), colorLeft1, i.texcoordMain.y-0.05);
				colorLeft1 = GetGrey(colorLeft1, 1, 0.5);
				
				fixed4 blendML1 = ScreenBlend(colorMain, colorLeft1)*_Left1Color;
				fixed4 bumpColorL1 = tex2D(_BumpTex, i.texcoordLeft1);
				bumpColorL1 = GetGrey(bumpColorL1, 0.9, 0.5);
				blendML1 = fixed4(BlendAdd(blendML1, bumpColorL1).rgb, 0);
				fixed4 L1MColor;
				L1MColor = lerp(L2MColor, blendML1, max(0, (1 / (1 - 0.35))*(0.35 - i.texcoordMain.x)));

				fixed4 LightColor = tex2D(_LightTex, i.texcoordMain);
				L1MColor *= LightColor;
				return L1MColor;
			}
			


		    
			//X方向的运动模糊方法
			fixed4 XMotionBlur(float2 texCoord, float BlurCenterX, fixed intensity, int IterationNumber, sampler2D tex)
			{
				//获取纹理坐标的xy
				float2 uv = texCoord.xy;
				//设置中心坐标
				float2 center = float2(BlurCenterX, texCoord.y);
				//获取坐标偏移量
				uv -= center;
				//初始化一个颜色值
				fixed4 color = fixed4(0, 0, 0, 0);
				//设置模糊权重
				intensity *= 0.085;
				//设置坐标缩放比例
				float scale = 1;
				//进行纹理颜色的迭代
				for (int j = 1; j < IterationNumber; ++j)
				{
					//迭代主纹理
					float2 t = texCoord + intensity * uv*j;
					color += tex2D(tex, t);
				}
				//最终将颜色值除以迭代次数，取平均值
				color /= (float)IterationNumber;
				return color;
			}

			//简单均值模糊
			fixed4 SimpleBlur(sampler2D tex,float2 texcoord) {

				float2 uv1 = texcoord + _Left2IterationNumber * _MainTex_TexelSize * float2(1, 1);
				float2 uv2 = texcoord + _Left2IterationNumber * _MainTex_TexelSize * float2(-1, 1);
				float2 uv3 = texcoord + _Left2IterationNumber * _MainTex_TexelSize * float2(-1, -1);
				float2 uv4 = texcoord + _Left2IterationNumber * _MainTex_TexelSize * float2(1, -1);

				fixed4 color = fixed4(0, 0, 0, 0);

				color += tex2D(tex, texcoord);
				color += tex2D(tex, uv1);
				color += tex2D(tex, uv2);
				color += tex2D(tex, uv3);
				color += tex2D(tex, uv4);

				//相加取平均，据说shader中乘法比较快
				return color * 0.2;
			}

			//去色方法,让阴影加重
			fixed4 GetGrey(fixed4 c,float rate,fixed lineValue)
			{
				fixed g = (c.r + c.g + c.b) / 3;
				if (g > lineValue)
				{
					g *= rate;
				}
				/*else {
					g /= rate;
				}*/
				return fixed4(g, g, g, c.a);
			}

			fixed4 FaceShadow(fixed4 c)
			{
				fixed4 color;
				color = -3 * pow(10, -5)*pow(c*255, 3) + 0.0132*pow(c*255, 2) - 0.3458*c*255 + 0.3916;
				return color/255;
			}

			//滤色混合
			fixed4 ScreenBlend(fixed4 c1, fixed4 c2)
			{
				fixed4 color = fixed4(1, 1, 1, 1);
				return (color - (color - c1)*(color - c2));
			}
			
			//柔光
			fixed4 SoftLight(fixed4 c1, fixed4 c2) {
				fixed4 color;
				if (length(c2) <= 0.5)
				{
					color = c1 * c2 * 2 + pow(c1, 2)*(fixed4(1, 1, 1, 1) - 2 * c2);
				}
				else{
					color = c1 * (fixed4(1, 1, 1, 1) - c2) * 2 + sqrt(c1)*(c2 * 2 - fixed4(1, 1, 1, 1));
				}
				return color;
			}

			//颜色减淡
			fixed4 BlendAdd(fixed4 c1, fixed4 c2)
			{
				return (c1 + c1 * c2 / (fixed4(1, 1, 1, 1) - c2));
			}

			//正常叠加
			fixed4 AddNormal(fixed4 src, fixed4 des)
			{
				fixed sr = src.a;
				fixed dr = 1.0 - sr;
				fixed4 src1 = fixed4(0,0,0,0);
				fixed4 des1 = src1;

				if (sr == 0.0) return des;
				if (des.a == 0.0 || dr == 0.0) return src;

				src.r = src.r > 0.0 ? src.r : 0.0;
				src.g = src.g > 0.0 ? src.g : 0.0;
				src.b = src.b > 0.0 ? src.b : 0.0;
				src.a = src.a > 0.0 ? src.a : 0.0;
				src1 = fixed4(sr*src.r, sr*src.g, sr*src.b, sr*src.a);

				des.r = des.r > 0.0 ? des.r : 0.0;
				des.g = des.g > 0.0 ? des.g : 0.0;
				des.b = des.b > 0.0 ? des.b : 0.0;
				des.a = des.a > 0.0 ? des.a : 0.0;
				des1 = fixed4(dr*des.r, dr*des.g, dr*des.b, dr*des.a);

				return src1 + des1;
			}

			//渐变颜色
			fixed4 gradient(fixed4 c1,fixed4 c2,float posX)
			{
				return lerp(c1, c2, posX);
			}
			//===========结束CG着色器语言编写模块===========  
			ENDCG
		}
		
	}
		
	FallBack "Diffuse"
}

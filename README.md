# Slayer Bars

Converts boss bars into 10 stacked/layered HP bars, where each bar peels off as the fight progresses. The design is used in some Asian action RPGs with bosses that have millions of health. Makes it easier to estimate HP %, predict mechs, and switch to execute rotation.

## How to edit art files

`.graphite` files are edited with the [free online Graphite vector editor](https://graphite.art/).

For creating DDS files, I like using [TextConv](https://github.com/microsoft/DirectXTex/releases) command line:

```
./texconv.exe -f dxt5 -m 0 -srgb -w 256 -h 256 -y mytexture.png
```


```
				<Texture name="$(parent)FrameLeft" textureFile="SlayerBars/media/frameoverlay.dds" layer="Frame" level="5">
					<Dimensions x="20" y="30"/>
					<Anchor point="TOPLEFT" relativeTo="$(parent)Status" relativePoint="TOPLEFT" offsetX="-11" offsetY="-2"/>
					<TextureCoords left="0.28125" right="0.46875" top="0.5390625" bottom="1"/>
				</Texture>
				<Texture name="$(parent)FrameCenter" textureFile="SlayerBars/media/frameoverlay.dds" layer="Frame" level="5">
					<Dimensions y="30"/>
					<AnchorFill/>
					<Anchor point="TOPLEFT" relativeTo="$(parent)Status" offsetX="9" offsetY="-2"/>
					<Anchor point="TOPRIGHT" relativeTo="$(parent)Status" offsetY="-2"/>
					<TextureCoords left="0.46875" right="0.722656" top="0.5390625" bottom="1"/>
				</Texture>
				<Texture name="$(parent)FrameRight" textureFile="SlayerBars/media/frameoverlay.dds" layer="Frame" level="5">
					<Dimensions x="5" y="30"/>
					<Anchor point="BOTTOMRIGHT" relativeTo="$(parent)Status" relativePoint="BOTTOMRIGHT" offsetX="3" offsetY="3"/>
					<TextureCoords left="0.722656" right="0.7636718" top="0.5390625" bottom="1"/>
				</Texture>
```

## Future Features

- (DPS Role Set) Off balance tracker
- (Tank Role set) Taunt tracker

## Credits

### Textures

- [Light Flare by freepik](https://www.freepik.com/free-psd/realistic-light-collection_408597479.htm)

- [Ink Splatters by starline on Freepik](https://www.freepik.com/free-vector/black-ink-drops-watercolor-abstract-splatters-design_10016813.htm#fromView=keyword&page=1&position=40&uuid=cdd063f2-b646-4228-82a9-86edf4388b42&query=Ink+strokes) and [strokes by freepik](https://www.freepik.com/free-vector/ink-brush-stroke-collection_11350210.htm#fromView=keyword&page=4&position=10&uuid=cdd063f2-b646-4228-82a9-86edf4388b42&query=Ink+strokes)

- [Claw Marks Vectors by Feri Saputra](https://www.vecteezy.com/vector-art/7164155-claw-scratch-vector-isolated-on-a-white-background-red-claw-mark-symbol-for-web-and-mobile-apps-vector-illustration)
- [Silver Circle Frame](https://www.vecteezy.com/vector-art/1310963-blue-and-silver-metallic-diamond-with-circle-frame)

- [Simple Health Bars by Cethiel](https://opengameart.org/content/simple-health-bars)


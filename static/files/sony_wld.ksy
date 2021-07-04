meta:
  id: sony_wld
  title: Sony WLD File Format
  file-extension: wld
  endian: le

# rethink flags
#  (flags & 0b10) >> 1 == 1 could be (flags & 0b10) != 0
#  look into kaitai's bitfield docs

doc: |
  Sony WLD Doc.
seq:
  - id: header
    type: header
    doc: WLD file header
  - id: string_hash
    type: xor_string(header.string_hash_bytes, header.string_count)
  - id: objects
    type: object
    repeat: expr
    repeat-expr: header.object_count
  - id: footer
    contents: [0xff, 0xff, 0xff, 0xff]

types:
  header:
    seq:
      - id: magic
        contents: [0x02, 0x3d, 0x50, 0x54]
      - id: version
        type: u4
      - id: object_count
        type: u4
      - id: region_count
        type: u4
      - id: max_object_bytes
        type: u4
      - id: string_hash_bytes
        type: u4
      - id: string_count
        type: u4


  xor_string:
    params:
      - id: length
        type: u2
      - id: count
        type: u2
    seq:
      - id: decoded
        size: length
        # wasn't able to get the key stored as a value instance
        process: xor([0x95, 0x3A, 0xC5, 0x2A, 0x95, 0x7A, 0x95, 0x6A])
        type: decoded_string_raw(count)
    types:
      decoded_string_raw:
        params:
          - id: repeats
            type: u2
        seq:
          - id: strings
            type: strz
            encoding: ASCII
            repeat: expr
            repeat-expr: repeats + 1
        instances:
          raw:
            pos: 0
            type: str
            encoding: ASCII
            size-eos: true

  string_hash_reference:
    doc: Decode and return the string at `position` in the `string_hash`
    params:
      - id: position
        type: u2
    instances:
      string:
        io: _root.string_hash.decoded._io
        pos: position * -1
        type: strz
        encoding: ASCII


  object:
    seq:
      - id: length
        type: u4
      - id: object_type
        type: u4
      - id: body
        size: length
        type:
          switch-on: object_type
          cases:
            0x3: object_type_03 # FRAME and BMINFO
            0x4: object_type_04 # SIMPLESPRITEDEF
            # 0x5: object_type_05 # merchant 25 I think
            0x6: object_type_06
            0x8: object_type_08
            0x12: object_type_12 # TRACKDEFINITION
            0x13: object_type_13 # TRACKINSTANCE
            0x1a: object_type_1a
            0x1b: object_type_1b
            0x1c: object_type_1c # part of pointlight
            0x21: object_type_21 # WORLDTREE
            0x28: object_type_28 # POINTLIGHT
            # 0x19 # SPHERELISTDEFINITION
            # _: object_type_unknown

  # FRAME and BMINFO
  # FRAME "filename" "name"
  object_type_03:
    seq:
      - id: name_reference
        type: s4
      - id: size1
        type: u4
      - id: filenames_length
        type: u2
      - id: filenames
        type: xor_string(filenames_length, size1)
    instances:
      name:
        type: string_hash_reference(name_reference)
      filename:
        value: filenames.decoded.strings.first

  # SIMPLESPRITEDEF
  object_type_04:
    doc: |
      ```
      SIMPLESPRITEDEF
        SIMPLESPRITETAG %s
        NUMFRAMES %d
        // repeated NUMFRAMES times
        FRAME "%s" "%s"
        CURRENTFRAME %d
        SLEEP %d
        SKIPFRAMES ON
      ENDSIMPLESPRITEDEF
      ```
    seq:
      - id: name_reference
        type: s4

      # bit 2 => CURRENTFRAME %d
      # bit 3 => SLEEP %d
      # bit 3 and 5 => SKIPFRAMES ON
      - id: flags
        type: s4
        # type: b16le

      # NUMFRAMES %d
      - id: frame_count
        type: u4

      # SLEEP %d
      - id: sleep
        type: u4
        if: animated == 1

      # points to 0x03 objects
      - id: frame_references
        type: u4
        repeat: expr
        repeat-expr: frame_count

    instances:
      # SIMPLESPRITETAG "%s"
      name:
        type: string_hash_reference(name_reference)
        # TODO: should it check if name_reference is 0
      animated:
        value: (flags & 0b1000) >> 3
      skip_frames:
        value: (flags & 0b101000) != 0


  # I think this is the ascii that is it generated from: im pretty confident
  # SIMPLESPRITEINST
  #   TAG "PIZZA_SPRITE"
  # ENDSIMPLESPRITEINST
  # object_type_05:

  # 2DSPRITEDEF
  object_type_06:
    doc: |
      #### Example
      ```
      2DSPRITEDEF
        2DSPRITETAG I_SWORDSPRITE
        CENTEROFFSET 0.0 1.0 0.0
        NUMFRAMES 2
        SLEEP 100
        SPRITESIZE 1.0 1.0
        NUMPITCHES 2
        PITCH 1
          PITCHCAP 512
          NUMHEADINGS 2
          HEADING 1
            HEADINGCAP 64
            FRAME "isword.bmp"  sword11
            FRAME "isword.bmp"  sword11
          ENDHEADING 1
          HEADING 2
            HEADINGCAP 128
            FRAME "isword.bmp" sword21
            FRAME "isword.bmp"  sword11
          ENDHEADING 2
        ENDPITCH 1
        PITCH 2
          PITCHCAP 256
          NUMHEADINGS 1
          HEADING 1
            HEADINGCAP 64
            FRAME "isword.bmp"  sword11
            FRAME "isword.bmp"  sword11
          ENDHEADING 1
        ENDPITCH 2
        // Default instance: render info
        RENDERMETHOD TEXTURE3
        // RENDERINFO block is optional
        RENDERINFO
          //TWOSIDED
          PEN 52
          BRIGHTNESS 1.000
          SCALEDAMBIENT 1.000
          UVORIGIN 0.5 0.4 0.3
          UAXIS 1.0 0.22 0.33 0.44
          VAXIS 1.0 0.25 0.35 0.45
        ENDRENDERINFO
      END2DSPRITEDEF
      ```
    meta:
      bit-endian: le
    seq:
      - id: name_reference
        type: s4
        doc: |
          The name of this sprite
      - id: flags
        type: sprite_flags
      - id: num_frames
        doc: |
          The number of frames present in each heading
        type: u4
      - id: num_pitches
        type: s4
        doc: |
          The number of pitches
      - id: sprite_size_x
        type: f4
        doc: |
          Scale the sprite by this amount in the x direction?
      - id: sprite_size_y
        type: f4
        doc: |
          Scale the sprite by this amount in the y direction?
      - id: sphere_fragment
        type: s4
        doc: |
          When SPHERE or SPHERELIST is defined this references a 0x22 fragment.
          When POLYHEDRON is defined this references a 0x18 fragment.
      - id: depth_scale
        type: f4
        if: flags.has_depth_scale
      - id: center_offset_x
        type: f4
        if: flags.has_center_offset
      - id: center_offset_y
        type: f4
        if: flags.has_center_offset
      - id: bounding_radius
        type: f4
        if: flags.has_bounding_radius
      - id: current_frame
        type: u4
        if: flags.has_current_frame
      - id: sleep
        type: s4
        if: flags.has_sleep
      - id: pitches
        type: sprite_pitch(num_frames)
        repeat: expr
        repeat-expr: num_pitches
      - id: render_method
        type: render_method
      - id: renderinfo_flags
        type: render_flags
      - id: pen
        type: s4
        if: renderinfo_flags.has_pen
      - id: brightness
        type: f4
        if: renderinfo_flags.has_brightness
      - id: scaled_ambient
        type: f4
        if: renderinfo_flags.has_scaled_ambient
      - id: uv_info
        type: uv_info
        if: renderinfo_flags.has_uv_info
    types:
      sprite_flags:
        seq:
          - id: has_center_offset
            type: b1
          - id: has_bounding_radius
            type: b1
          - id: has_current_frame
            type: b1
          - id: has_sleep
            type: b1
          - id: flag04
            type: b1
          - id: flag05
            type: b1
          - id: skip_frames
            type: b1
          - id: has_depth_scale
            type: b1
          - id: flag08
            type: b1
          - id: flag09
            type: b1
          - id: flag10
            type: b1
          - id: flag11
            type: b1
          - id: flag12
            type: b1
          - id: flag13
            type: b1
          - id: flag14
            type: b1
          - id: flag15
            type: b1
          - id: flag16
            type: b1
          - id: flag17
            type: b1
          - id: flag18
            type: b1
          - id: flag19
            type: b1
          - id: flag20
            type: b1
          - id: flag21
            type: b1
          - id: flag22
            type: b1
          - id: flag23
            type: b1
          - id: flag24
            type: b1
          - id: flag25
            type: b1
          - id: flag26
            type: b1
          - id: flag27
            type: b1
          - id: flag28
            type: b1
          - id: flag29
            type: b1
          - id: flag30
            type: b1
          - id: flag31
            type: b1
      sprite_pitch:
        params:
          - id: num_frames
            type: u4
        seq:
          - id: pitch_cap
            type: s4
          - id: num_headings
            type: b31
          - id: top_or_bottom_view
            type: b1
          - id: headings
            type: sprite_heading(num_frames)
            repeat: expr
            repeat-expr: num_headings
      sprite_heading:
        params:
          - id: num_frames
            type: u4
        seq:
          - id: heading_cap
            type: s4
          - id: frames
            type: u4
            repeat: expr
            repeat-expr: num_frames
      render_method:
        doc: |
          ```
          SOLIDFILL                    = 0x007 = 0b_0000_0000_0111
          SOLIDFILLAMBIENT             = 0x013 = 0b_0000_0001_0011
          SOLIDFILLCONSTANT            = 0x00b = 0b_0000_0000_1011
          SOLIDFILLSCALEDAMBIENT       = 0x017 = 0b_0000_0001_0111
          SOLIDFILLZEROINTENSITY       = 0x003 = 0b_0000_0000_0011

          TEXTURE1                     = 0x107 = 0b_0001_0000_0111
          TEXTURE2                     = 0x207 = 0b_0010_0000_0111
          TEXTURE3                     = 0x307 = 0b_0011_0000_0111
          TEXTURE4                     = 0x407 = 0b_0100_0000_0111
          TEXTURE5                     = 0x507 = 0b_0101_0000_0111

          TEXTURE1AMBIENT              = 0x113 = 0b_0001_0001_0011
          TEXTURE2AMBIENT              = 0x213 = 0b_0010_0001_0011
          TEXTURE3AMBIENT              = 0x313 = 0b_0011_0001_0011
          TEXTURE4AMBIENT              = 0x413 = 0b_0100_0001_0011
          TEXTURE5AMBIENT              = 0x513 = 0b_0101_0000_0011

          TEXTURE1CONSTANT             = 0x10b = 0b_0001_0000_1011
          TEXTURE2CONSTANT             = 0x20b = 0b_0010_0000_1011
          TEXTURE3CONSTANT             = 0x30b = 0b_0011_0000_1011
          TEXTURE4CONSTANT             = 0x40b = 0b_0100_0000_1011
          TEXTURE5CONSTANT             = 0x50b = 0b_0101_0000_1011

          TEXTURE1SCALEDAMBIENT        = 0x117 = 0b_0001_0001_0111
          TEXTURE2SCALEDAMBIENT        = 0x213 = 0b_0010_0001_0111
          TEXTURE3SCALEDAMBIENT        = 0x313 = 0b_0011_0001_0111
          TEXTURE4SCALEDAMBIENT        = 0x413 = 0b_0100_0001_0111
          TEXTURE5SCALEDAMBIENT        = 0x513 = 0b_0101_0000_0111

          TEXTURE1ZEROINTENSITY        = 0x003 = 0b_0000_0000_0011
          TEXTURE2ZEROINTENSITY        = 0x003 = 0b_0000_0000_0011
          TEXTURE3ZEROINTENSITY        = 0x003 = 0b_0000_0000_0011
          TEXTURE4ZEROINTENSITY        = 0x003 = 0b_0000_0000_0011
          TEXTURE5ZEROINTENSITY        = 0x003 = 0b_0000_0000_0011

          TRANSTEXTURE1                = 0x187 = 0b_0001_1000_0111
          TRANSTEXTURE2                = 0x287 = 0b_0010_1000_0111
          TRANSTEXTURE4                = 0x487 = 0b_0100_1000_0111
          TRANSTEXTURE5                = 0x587 = 0b_0101_1000_0111

          TRANSTEXTURE1AMBIENT         = 0x193 = 0b_0001_1001_0011
          TRANSTEXTURE2AMBIENT         = 0x293 = 0b_0010_1001_0011
          TRANSTEXTURE4AMBIENT         = 0x493 = 0b_0100_1001_0011
          TRANSTEXTURE5AMBIENT         = 0x593 = 0b_0101_1001_0011

          TRANSTEXTURE1CONSTANT        = 0x18b = 0b_0001_1000_1011
          TRANSTEXTURE2CONSTANT        = 0x18b = 0b_0010_1000_1011
          TRANSTEXTURE4CONSTANT        = 0x18b = 0b_0100_1000_1011
          TRANSTEXTURE5CONSTANT        = 0x18b = 0b_0101_1000_1011

          TRANSTEXTURE1SCALEDAMBIENT   = 0x197 = 0b_0001_1001_0111
          TRANSTEXTURE2SCALEDAMBIENT   = 0x297 = 0b_0010_1001_0111
          TRANSTEXTURE4SCALEDAMBIENT   = 0x497 = 0b_0100_1001_0111
          TRANSTEXTURE5SCALEDAMBIENT   = 0x597 = 0b_0101_1001_0111

          TRANSTEXTURE1ZEROINTENSITY   = 0x183 = 0b_0001_1000_0011
          TRANSTEXTURE2ZEROINTENSITY   = 0x283 = 0b_0010_1000_0011
          TRANSTEXTURE4ZEROINTENSITY   = 0x483 = 0b_0100_1000_0011
          TRANSTEXTURE5ZEROINTENSITY   = 0x583 = 0b_0101_1000_0011

          USERDEFINED %d               =  %d
          ```
        seq:
          - id: flag00
            type: b1
            doc: |
              Always set for known values
          - id: flag01
            type: b1
            doc: |
              Always set for known values
          - id: flag02
            type: b1
          - id: constant
            type: b1
            doc: |
              Render with constant color value?
          - id: ambient
            type: b1
            doc: |
              Render with ambient lighting?
          - id: flag05
            type: b1
          - id: flag06
            type: b1
          - id: transparent
            type: b1
            doc: |
              Enable texture transparency?
          - id: num_tex_coords
            type: b3
            doc: |
              The number of texture coordinates
          - id: ukn
            type: b21
      render_flags:
        seq:
          - id: has_pen
            type: b1
          - id: has_brightness
            type: b1
          - id: has_scaled_ambient
            type: b1
          - id: flag03
            type: b1
          - id: has_uv_info
            type: b1
          - id: flag05
            type: b1
          - id: flag06
            type: b1
          - id: flag07
            type: b1
          - id: flag08
            type: b1
          - id: flag09
            type: b1
          - id: flag10
            type: b1
          - id: flag11
            type: b1
          - id: flag12
            type: b1
          - id: flag13
            type: b1
          - id: flag14
            type: b1
          - id: flag15
            type: b1
          - id: flag16
            type: b1
          - id: flag17
            type: b1
          - id: flag18
            type: b1
          - id: flag19
            type: b1
          - id: flag20
            type: b1
          - id: flag21
            type: b1
          - id: flag22
            type: b1
          - id: flag23
            type: b1
          - id: flag24
            type: b1
          - id: flag25
            type: b1
          - id: flag26
            type: b1
          - id: flag27
            type: b1
          - id: flag28
            type: b1
          - id: flag29
            type: b1
          - id: flag30
            type: b1
          - id: flag31
            type: b1
      uv_info:
        seq:
          - id: uv_origin_x
            type: f4
          - id: uv_origin_y
            type: f4
          - id: uv_origin_z
            type: f4
          - id: u_axis_x
            type: f4
          - id: u_axis_y
            type: f4
          - id: u_axis_z
            type: f4
          - id: v_axis_x
            type: f4
          - id: v_axis_y
            type: f4
          - id: v_axis_z
            type: f4
    instances:
      name:
        type: string_hash_reference(name_reference)

  # Added by 3DSPRITEDEF
  # massive - the whole bsp nodes and everything.
  object_type_08:
    seq:
      - id: unk
        type: u1

  # TRACKDEFINITION
  object_type_12:
    seq:
      # TAG
      - id: name_reference
        type: s4
      # unk
      - id: flags
        type: u4
      # NUMFRAMES %d
      - id: frame_count
        type: u4
      - id: frames
        type: frame_transform
        repeat: expr
        repeat-expr: frame_count
        # TODO: handle fields added by flags
    types:
      frame_transform:
        seq:
          - id: rotate_denominator
            type: f4
          - id: rotate_x_numerator
            type: f4
          - id: rotate_y_numerator
            type: f4
          - id: rotate_z_numerator
            type: f4
          - id: shift_x_numerator
            type: f4
          - id: shift_y_numerator
            type: f4
          - id: shift_z_numerator
            type: f4
          - id: shift_denominator
            type: f4

    instances:
      name:
        type: string_hash_reference(name_reference)

  # TRACKINSTANCE
  object_type_13:
    seq:
      # TAG
      - id: name_reference
        type: s4

      - id: track_reference
        type: u4

      # bit 0 => sleep
      # bit 1 => reverse
      # bit 2 => interpolate
      - id: flags
        type: u4

      - id: sleep
        type: u4
        if: (flags & 0b1) == 1

    instances:
      name:
        type: string_hash_reference(name_reference)
      interpolate:
        value: (flags & 0b100) >> 2 == 1
      reverse:
        value: (flags & 0b10) >> 1 == 1

  # Added by 3DSPRITEDEF
  # No idea what this one is trying to do, will need to see if changing the file changes this object.
  # maybe this is the spherelist def?
  # could check mapedit for an example spherelist with more data
  object_type_1a:
    seq:
      - id: unk1
        type: u4
      # might be a name_ref
      - id: unk2
        type: s4
      - id: unk3
        type: u4

  # LIGHTDEFINITION
  # unable to test CURRENTFRAME or multiple frames/colors.
  object_type_1b:
    seq:
      - id: name_reference
        type: s4

      # bit 0 => CURRENTFRAME %d
      # bit 1 => SLEEP %d
      # bit 2 => LIGHTLEVELS %f
      # bit 3 => SKIPFRAMES ON
      # bit 4 and 1 => COLOR
      - id: flags
        type: s4
        # type: b16le

      # NUMFRAMES
      - id: frame_count
        type: u4
      # SLEEP %d
      - id: sleep
        type: u4
        if: (flags & 0b10) >> 1 == 1
      # LIGHTLEVELS %f
      - id: light_levels
        type: f4
        if: (flags & 0b100) >> 2 == 1
      # COLOR  %f %f %f
      - id: colors
        type: color_rgb
        repeat: expr
        repeat-expr: frame_count
        if: (flags & 0b1010) != 0 and frame_count != 0

    types:
      color_rgb:
        seq:
          - id: red
            type: f4
          - id: green
            type: f4
          - id: blue
            type: f4

    instances:
      name:
        type: string_hash_reference(name_reference)
      # SKIPFRAMES ON
      skip_frames:
        value: (flags & 0b1000) >> 3 == 1

  # LIGHT "%s"
  # unk fields were both 0 even with all the added instructions
  object_type_1c:
    seq:
      # always 0?
      - id: unk1
        type: u4
      - id: name_reference
        type: s4
      # always 0?
      - id: unk2
        type: u4
    instances:
      name:
        type: string_hash_reference(name_reference)

  # WORLDTREE
  object_type_21:
    seq:
      - id: unk
        type: u4

      # NUMWORLDNODES %d
      - id: world_node_count
        type: u4

      # WORLDNODE
      - id: world_nodes
        type: world_node
        repeat: expr
        repeat-expr: world_node_count
    types:
      world_node:
        seq:
          # NORMALABCD %f %f %f %f
          - id: normal_a
            type: f4
          - id: normal_b
            type: f4
          - id: normal_c
            type: f4
          - id: normal_d
            type: f4

          # WORLDREGIONTAG %d
          - id: region_tag
            type: u4
          # TODO: revisit with more examples and add conditions when region isn't zero

          # FRONTTREE %d
          - id: front_tree
            type: u4
            if: region_tag == 0

          # BACKTREE %d
          - id: back_tree
            type: u4
            if: region_tag == 0

  # POINTLIGHT
  object_type_28:
    seq:
      # TAG
      - id: name_reference
        type: s4
      - id: light_reference
        type: s4

      # bit 5 => STATIC
      # bit 6 => STATICINFLUENCE
      # bit 7 => NUMREGIONS and REGIONS
      - id: flags
        type: u4

      # XYZ %f, %f, %f
      - id: x
        type: f4
      - id: y
        type: f4
      - id: z
        type: f4

      # RADIUSOFINFLUENCE
      - id: radius
        type: f4

      # NUMREGIONS %d
      - id: region_count
        type: u4
        if: (flags & 0b10000000) != 0

      # REGIONS %d
      # values are offset by 1
      # REGIONS 0, 3, 5
      # becomes -1, 2, 4
      - id: regions
        type: s4
        repeat: expr
        repeat-expr: region_count
        if: (flags & 0b10000000) != 0

    instances:
      name:
        type: string_hash_reference(name_reference)
        if: name_reference != 0
      static:
        value: (flags & 0b100000) != 0
      static_influence:
        value: (flags & 0b1000000) != 0

  # # object_type_unknown:

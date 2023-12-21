# ucas-ca-lab
## bench of div and mul has been released in branch exp10_pipeline 
- to test the div module or mul module, use test_<module_name>.v as simulation and <module_name>.v as design
- div_0_gen is signed and div_1_gen is unsigned
- mul_test do signed mul, replace
```v
assign tempans = $signed(extended_x) * $signed(extended_y) ;
```
with your module.

## How to add cache RAMs

search IP catalog: `Block Memory Generator`

- tagv:

  ![image-20231220234105513](./img/image-20231220234105513.png)

  ![image-20231220234143961](./img/image-20231220234143961.png)

- data:

  ![image-20231220234307048](./img/image-20231220234307048.png)

  ![image-20231220234329044](./img/image-20231220234329044.png)




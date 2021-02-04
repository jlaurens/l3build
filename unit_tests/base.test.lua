-- See README.md for instructions

assert(af, "No assertion framework available")

function test_base()
  af.assert_true(true)
  af.assert_is_nil(nil)
end

function test_flag()
  local flag1 = af.new_flag()
  local flag2 = af.new_flag()
  flag1.expect("")
  flag2.expect("")
  flag1.push(1)
  flag2.push(2)
  flag1.expect(1)
  flag2.expect(2)
  flag1.expect("1")
  flag2.expect("2")
  flag1.push(2)
  flag2.shift(1)
  flag1.expect("1/2")
  flag2.expect("1/2")
end

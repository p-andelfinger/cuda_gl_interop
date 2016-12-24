#include "cuda_gl_interop.h"
#include "cuda_check_error.h"

#include "SFML/Graphics.hpp"
#include "SFML/Graphics/Image.hpp"

#define THREADS_PER_BLOCK 256

#define WIDTH 1024
#define HEIGHT 768

__global__ void update_surface(cudaSurfaceObject_t surface)
{
  int x = threadIdx.x + blockIdx.x * blockDim.x;
  int y = threadIdx.y + blockIdx.y * blockDim.y;

  if(x >= WIDTH)
    return;

  uchar4 pixel = { x & 0xff, x & 0xff, x & 0xff, 0xff };

  surf2Dwrite(pixel, surface, x * sizeof(uchar4), y);
}

int main(int argc, char **argv)
{
  sf::RenderWindow window(sf::VideoMode(WIDTH, HEIGHT), "cuda_gl_interop");

  sf::Sprite sprite;
  sf::Texture txture;
  txture.create(WIDTH, HEIGHT);
  
  cudaArray *bitmap_d;

  GLuint gl_tex_handle = txture.getNativeHandle();

  cudaGraphicsResource *cuda_tex_handle;

  cudaGraphicsGLRegisterImage(&cuda_tex_handle, gl_tex_handle, GL_TEXTURE_2D,
                              cudaGraphicsRegisterFlagsNone);
  cudaCheckError();

  cudaGraphicsMapResources(1, &cuda_tex_handle, 0);
  cudaCheckError();

  cudaGraphicsSubResourceGetMappedArray(&bitmap_d, cuda_tex_handle, 0, 0);
  cudaCheckError();

  struct cudaResourceDesc resDesc;
  memset(&resDesc, 0, sizeof(resDesc));
  resDesc.resType = cudaResourceTypeArray;

  resDesc.res.array.array = bitmap_d;
  cudaSurfaceObject_t bitmap_surface = 0;
  cudaCreateSurfaceObject(&bitmap_surface, &resDesc);
  cudaCheckError();

  sprite.setTexture(txture);

  dim3 blocks(ceil((float)WIDTH / THREADS_PER_BLOCK), HEIGHT);

  while(!sf::Keyboard::isKeyPressed(sf::Keyboard::Escape))
  {
    update_surface<<<blocks, THREADS_PER_BLOCK>>>(bitmap_surface);
    cudaCheckError();

    cudaDeviceSynchronize();
    cudaCheckError();

    window.draw(sprite);
    window.display();
  }

  return 0;
}
